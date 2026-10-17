package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.common.time.UserTime;
import com.blistra.finance.domain.Expense;
import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.Settlement;
import com.blistra.finance.dto.ExpenseResponse;
import com.blistra.finance.dto.FriendDetailResponse;
import com.blistra.finance.dto.FriendResponse;
import com.blistra.finance.dto.SettlementRequest;
import com.blistra.finance.dto.SettlementResponse;
import com.blistra.finance.dto.UserSummary;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.finance.repository.SettlementRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * "Settle up" payments between two people. Either side may record one, in
 * either direction, as long as they are friends or still share a balance.
 */
@Service
@Transactional(readOnly = true)
public class SettlementService {

    private static final int DETAIL_EXPENSE_LIMIT = 200;

    private final SettlementRepository settlementRepository;
    private final ExpenseRepository expenseRepository;
    private final ExpenseService expenseService;
    private final FriendService friendService;
    private final BalanceService balanceService;
    private final FinanceUsers financeUsers;
    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;
    @org.springframework.beans.factory.annotation.Autowired
    private FinanceGroupService groups;
    @org.springframework.beans.factory.annotation.Autowired
    private FinanceHistoryService history;

    public SettlementService(SettlementRepository settlementRepository,
                             ExpenseRepository expenseRepository,
                             ExpenseService expenseService,
                             FriendService friendService,
                             BalanceService balanceService,
                             FinanceUsers financeUsers,
                             CurrentUserProvider currentUserProvider,
                             UserTime userTime) {
        this.settlementRepository = settlementRepository;
        this.expenseRepository = expenseRepository;
        this.expenseService = expenseService;
        this.friendService = friendService;
        this.balanceService = balanceService;
        this.financeUsers = financeUsers;
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
    }

    @Transactional
    public SettlementResponse create(SettlementRequest request) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        UUID friend = request.friendId();
        if (friend.equals(me)) {
            throw new BadRequestException("Choose a friend to settle up with");
        }
        if (request.groupId() != null) {
            var members = groups.acceptedMemberIds(request.groupId(),me);
            if (!members.contains(friend)) throw new ResourceNotFoundException("Group member not found");
        } else if (!friendService.areFriends(me, friend) && !balanceService.balances(me).containsKey(friend)) {
            throw new ResourceNotFoundException("Friend not found");
        }
        BigDecimal amount = Money.parse(request.amount());
        if (amount.signum() <= 0) {
            throw new BadRequestException("Amount must be more than zero");
        }
        boolean iPaid = request.direction() == SettlementRequest.Direction.I_PAID;
        Settlement settlement = new Settlement(me, iPaid ? me : friend, iPaid ? friend : me, amount,
                request.currency(), request.settledOn() != null ? request.settledOn() : userTime.today(),
                request.note() == null || request.note().isBlank() ? null : request.note().trim());
        settlement.setGroupId(request.groupId());
        settlementRepository.saveAndFlush(settlement);
        history.settlement(settlement,"PENDING",me);
        return toResponses(List.of(settlement), me).get(0);
    }

    @Transactional
    public void delete(UUID id) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Settlement settlement = settlementRepository.lockForDecision(id)
                .filter(s -> s.involves(me))
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));
        if (!settlement.getCreatedBy().equals(me)) {
            throw new BadRequestException("Only the person who recorded this payment can delete it");
        }
        if (java.util.Set.of("CONFIRMED","LEGACY_RECORDED").contains(settlement.getStatus())) {
            throw new BadRequestException("Confirmed payments cannot be deleted. Record a correcting payment for confirmation.");
        }
        history.settlement(settlement,"DELETED",me);
        settlementRepository.delete(settlement);
    }

    @Transactional
    public SettlementResponse decide(UUID id, boolean confirmed) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Settlement settlement = settlementRepository.lockForDecision(id)
                .filter(s -> s.involves(me))
                .orElseThrow(() -> new ResourceNotFoundException("Payment not found"));
        if (settlement.getCreatedBy().equals(me)) {
            throw new BadRequestException("Only the other participant can confirm or reject this payment");
        }
        String target = confirmed ? "CONFIRMED" : "REJECTED";
        if (!"PENDING".equals(settlement.getStatus()) && !target.equals(settlement.getStatus())) {
            throw new com.blistra.common.exception.InvalidStateException("This payment has already been decided");
        }
        if ("PENDING".equals(settlement.getStatus())) {
            settlement.decide(confirmed);
            history.settlement(settlement,target,me);
        }
        settlementRepository.saveAndFlush(settlement);
        return toResponses(List.of(settlement), me).get(0);
    }

    public List<SettlementResponse> list(UUID friendId) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        return toResponses(settlementRepository.findInvolving(me, friendId), me);
    }

    public List<SettlementResponse> groupList(UUID groupId) {
        UUID me=currentUserProvider.getCurrentUser().getId();
        groups.requireMember(groupId,me);
        return toResponses(settlementRepository.findByGroupIdOrderByCreatedAtDesc(groupId,
                org.springframework.data.domain.PageRequest.of(0,200)).getContent(),me);
    }

    /** Balance, shared expenses and repayments with one person. */
    public FriendDetailResponse friendDetail(UUID friendId) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        boolean friends = friendService.areFriends(me, friendId);
        Map<String, BigDecimal> balance = balanceService.balances(me).get(friendId);
        List<Expense> expenses = expenseRepository.search(me, friendId, null, null, null, null,
                PageRequest.of(0, DETAIL_EXPENSE_LIMIT,
                        Sort.by(Sort.Direction.DESC, "spentOn").and(Sort.by(Sort.Direction.DESC, "createdAt"))))
                .getContent();
        List<Settlement> settlements = settlementRepository.findInvolving(me, friendId);
        if (!friends && balance == null && expenses.isEmpty() && settlements.isEmpty()) {
            throw new ResourceNotFoundException("Friend not found");
        }
        UserSummary user = FinanceUsers.of(financeUsers.summaries(List.of(friendId)), friendId);
        List<ExpenseResponse> expenseResponses = expenseService.toResponses(expenses, me);
        return new FriendDetailResponse(
                new FriendResponse(user, friends, null, BalanceService.toList(balance)),
                expenseResponses, toResponses(settlements, me));
    }

    private List<SettlementResponse> toResponses(List<Settlement> settlements, UUID me) {
        Set<UUID> ids = new HashSet<>();
        settlements.forEach(s -> {
            ids.add(s.getPayerId());
            ids.add(s.getPayeeId());
        });
        Map<UUID, UserSummary> users = financeUsers.summaries(ids);
        return settlements.stream()
                .map(s -> new SettlementResponse(s.getId(), FinanceUsers.of(users, s.getPayerId()),
                        FinanceUsers.of(users, s.getPayeeId()), Money.toPlainString(s.getAmount()),
                        s.getCurrency(), s.getSettledOn(), s.getNote(),
                        s.getCreatedBy().equals(me) && java.util.Set.of("PENDING","REJECTED").contains(s.getStatus()),
                        s.getCreatedAt(), s.getStatus(),
                        s.involves(me) && !s.getCreatedBy().equals(me) && "PENDING".equals(s.getStatus()),s.getGroupId()))
                .toList();
    }
}
