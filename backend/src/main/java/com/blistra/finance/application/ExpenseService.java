package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.common.time.UserTime;
import com.blistra.finance.domain.Expense;
import com.blistra.finance.domain.ExpenseCategory;
import com.blistra.finance.domain.ExpenseShare;
import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.SplitType;
import com.blistra.finance.dto.ExpenseRequest;
import com.blistra.finance.dto.ExpenseResponse;
import com.blistra.finance.dto.PageResponse;
import com.blistra.finance.dto.ParticipantInput;
import com.blistra.finance.dto.ShareResponse;
import com.blistra.finance.dto.UserSummary;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Logs personal and shared expenses.
 *
 * <p>Everyone involved (payer and share holders) can see an expense; only
 * its creator can change or delete it. Apart from the creator, everyone on a
 * new expense must be an accepted friend of the creator.</p>
 */
@Service
@Transactional(readOnly = true)
public class ExpenseService {

    private static final int MAX_PAGE_SIZE = 100;

    private final ExpenseRepository expenseRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FriendService friendService;
    private final FinanceUsers financeUsers;
    private final UserTime userTime;

    public ExpenseService(ExpenseRepository expenseRepository,
                          CurrentUserProvider currentUserProvider,
                          FriendService friendService,
                          FinanceUsers financeUsers,
                          UserTime userTime) {
        this.expenseRepository = expenseRepository;
        this.currentUserProvider = currentUserProvider;
        this.friendService = friendService;
        this.financeUsers = financeUsers;
        this.userTime = userTime;
    }

    @Transactional
    public ExpenseResponse create(ExpenseRequest request) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Expense expense = new Expense(me);
        apply(expense, request, me, friendService.acceptedFriendIds(me));
        Expense saved = expenseRepository.save(expense);
        return toResponses(List.of(saved), me).get(0);
    }

    @Transactional
    public ExpenseResponse update(UUID id, ExpenseRequest request) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Expense expense = requireEditable(id, me);
        // People already on the expense may stay even if no longer friends.
        Set<UUID> allowed = new HashSet<>(friendService.acceptedFriendIds(me));
        allowed.add(expense.getPaidBy());
        expense.getShares().forEach(s -> allowed.add(s.getUserId()));
        // Hibernate flushes inserts before orphan deletes; drop the old shares
        // first so re-adding a person can't trip the (expense, user) unique key.
        expense.replaceShares(List.of());
        expenseRepository.flush();
        apply(expense, request, me, allowed);
        return toResponses(List.of(expenseRepository.saveAndFlush(expense)), me).get(0);
    }

    @Transactional
    public void delete(UUID id) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        expenseRepository.delete(requireEditable(id, me));
    }

    public ExpenseResponse get(UUID id) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Expense expense = expenseRepository.findById(id)
                .filter(e -> e.involves(me))
                .orElseThrow(() -> new ResourceNotFoundException("Expense not found"));
        return toResponses(List.of(expense), me).get(0);
    }

    public PageResponse<ExpenseResponse> list(LocalDate from, LocalDate to, ExpenseCategory category,
                                              UUID friendId, String query, int page, int size) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        String like = query == null || query.isBlank() ? null : "%" + query.trim().toLowerCase() + "%";
        PageRequest pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE),
                Sort.by(Sort.Direction.DESC, "spentOn").and(Sort.by(Sort.Direction.DESC, "createdAt")));
        Page<Expense> result = expenseRepository.search(me, friendId, from, to, category, like, pageable);
        List<ExpenseResponse> content = toResponses(result.getContent(), me);
        return new PageResponse<>(content, result.getNumber(), result.getSize(), result.getTotalElements(),
                result.getTotalPages(), result.isLast());
    }

    /** Batch-maps expenses, resolving every user name in one lookup. */
    public List<ExpenseResponse> toResponses(List<Expense> expenses, UUID me) {
        Set<UUID> ids = new HashSet<>();
        for (Expense e : expenses) {
            ids.add(e.getPaidBy());
            ids.add(e.getCreatedBy());
            e.getShares().forEach(s -> ids.add(s.getUserId()));
        }
        Map<UUID, UserSummary> users = financeUsers.summaries(ids);
        List<ExpenseResponse> responses = new ArrayList<>();
        for (Expense e : expenses) {
            BigDecimal myShare = e.shareOf(me);
            BigDecimal paid = e.getPaidBy().equals(me) ? e.getAmount() : BigDecimal.ZERO;
            List<ShareResponse> shares = e.getShares().stream()
                    .map(s -> new ShareResponse(FinanceUsers.of(users, s.getUserId()),
                            Money.toPlainString(s.getAmount()),
                            s.getInputValue() == null ? null : s.getInputValue().stripTrailingZeros().toPlainString()))
                    .toList();
            responses.add(new ExpenseResponse(e.getId(), e.getDescription(), e.getCategory(),
                    Money.toPlainString(e.getAmount()), e.getCurrency(), e.getSpentOn(), e.getNotes(),
                    e.getSplitType(), FinanceUsers.of(users, e.getPaidBy()), FinanceUsers.of(users, e.getCreatedBy()),
                    shares, Money.toPlainString(myShare), Money.toPlainString(paid.subtract(myShare)),
                    e.getCreatedBy().equals(me), e.getCreatedAt()));
        }
        return responses;
    }

    private Expense requireEditable(UUID id, UUID me) {
        Expense expense = expenseRepository.findById(id)
                .filter(e -> e.involves(me))
                .orElseThrow(() -> new ResourceNotFoundException("Expense not found"));
        if (!expense.getCreatedBy().equals(me)) {
            throw new BadRequestException("Only the person who added this expense can change it");
        }
        return expense;
    }

    private void apply(Expense expense, ExpenseRequest request, UUID me, Collection<UUID> allowed) {
        BigDecimal amount = Money.parse(request.amount());
        if (amount.signum() <= 0) {
            throw new BadRequestException("Amount must be more than zero");
        }
        String description = request.description().trim();
        if (description.isEmpty()) {
            throw new BadRequestException("Add a short description");
        }
        List<ParticipantInput> participants = request.participants() == null ? List.of() : request.participants();
        SplitType type = request.splitType() != null ? request.splitType()
                : participants.isEmpty() ? SplitType.NONE : SplitType.EQUAL;
        UUID payer = request.paidBy() != null ? request.paidBy() : me;

        List<SplitCalculator.Share> shares;
        if (type == SplitType.NONE) {
            boolean onlyMe = participants.stream().allMatch(p -> p.userId().equals(me));
            if (!onlyMe || !payer.equals(me)) {
                throw new BadRequestException("Choose how to split an expense shared with others");
            }
            shares = List.of(new SplitCalculator.Share(me, amount, null));
        } else {
            Set<UUID> everyone = new LinkedHashSet<>();
            everyone.add(payer);
            participants.forEach(p -> everyone.add(p.userId()));
            if (!everyone.contains(me)) {
                throw new BadRequestException("You must be part of an expense you add");
            }
            if (everyone.size() < 2) {
                throw new BadRequestException("Add at least one friend to split with");
            }
            for (UUID user : everyone) {
                if (!user.equals(me) && !allowed.contains(user)) {
                    throw new BadRequestException("You can only split expenses with accepted friends");
                }
            }
            List<SplitCalculator.Input> inputs = participants.stream()
                    .map(p -> new SplitCalculator.Input(p.userId(), parseValue(p.value(), type)))
                    .toList();
            shares = SplitCalculator.split(amount, type, inputs);
        }

        expense.setDescription(description);
        expense.setCategory(request.category());
        expense.setAmount(amount);
        expense.setCurrency(request.currency());
        expense.setSpentOn(request.spentOn() != null ? request.spentOn()
                : expense.getSpentOn() != null ? expense.getSpentOn() : userTime.today());
        expense.setNotes(request.notes() == null || request.notes().isBlank() ? null : request.notes().trim());
        expense.setPaidBy(payer);
        expense.setSplitType(type);
        List<ExpenseShare> entities = shares.stream()
                .filter(s -> s.amount().signum() > 0 || s.inputValue() != null)
                .map(s -> new ExpenseShare(s.userId(), s.amount(), s.inputValue()))
                .toList();
        expense.replaceShares(entities);
    }

    private static BigDecimal parseValue(String raw, SplitType type) {
        if (type == SplitType.EQUAL || raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return new BigDecimal(raw.trim());
        } catch (NumberFormatException ex) {
            throw new BadRequestException("Invalid split value: " + raw);
        }
    }
}
