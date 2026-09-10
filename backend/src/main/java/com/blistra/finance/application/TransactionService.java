package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.AccountStatus;
import com.blistra.finance.domain.Category;
import com.blistra.finance.domain.CategoryStatus;
import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.PageResponse;
import com.blistra.finance.dto.TransactionRequest;
import com.blistra.finance.dto.TransactionResponse;
import com.blistra.finance.repository.AccountRepository;
import com.blistra.finance.repository.CategoryRepository;
import com.blistra.finance.repository.FinanceTransactionRepository;
import com.blistra.finance.repository.FinanceTransactionSpecifications;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class TransactionService {

    private static final int MAX_PAGE_SIZE = 100;

    private final FinanceTransactionRepository transactionRepository;
    private final AccountRepository accountRepository;
    private final CategoryRepository categoryRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FinanceMapper mapper;

    public TransactionService(FinanceTransactionRepository transactionRepository,
                              AccountRepository accountRepository,
                              CategoryRepository categoryRepository,
                              CurrentUserProvider currentUserProvider,
                              FinanceMapper mapper) {
        this.transactionRepository = transactionRepository;
        this.accountRepository = accountRepository;
        this.categoryRepository = categoryRepository;
        this.currentUserProvider = currentUserProvider;
        this.mapper = mapper;
    }

    @Transactional
    public TransactionResponse create(TransactionRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Account account = requireOwnedAccount(request.getAccountId(), user.getId());
        Category category = requireOwnedCategory(request.getCategoryId(), user.getId());
        BigDecimal amount = requirePositiveAmount(request.getAmount(), "amount");
        LocalDate occurredAt = request.getOccurredAt() != null ? request.getOccurredAt() : LocalDate.now();
        if (category.getType() != toCategoryType(request.getType())) {
            throw new BadRequestException(
                    "Transaction type does not match the category type ("
                            + category.getType().name().toLowerCase() + " category)");
        }
        var transaction = new com.blistra.finance.domain.FinanceTransaction(
                user, account, category, request.getType(), amount, account.getCurrency(),
                occurredAt, request.getDescription(), request.getNotes());
        return mapper.toTransactionResponse(transactionRepository.save(transaction));
    }

    public PageResponse<TransactionResponse> list(UUID accountId, UUID categoryId,
                                                  com.blistra.finance.domain.TransactionType type,
                                                  LocalDate from, LocalDate to,
                                                  BigDecimal amountMin, BigDecimal amountMax,
                                                  int page, int size) {
        User user = currentUserProvider.getCurrentUser();
        if (accountId != null && !accountRepository.existsByIdAndUserId(accountId, user.getId())) {
            throw new ResourceNotFoundException("Account not found");
        }
        if (categoryId != null && !categoryRepository.existsByIdAndUserId(categoryId, user.getId())) {
            throw new ResourceNotFoundException("Category not found");
        }
        int boundedSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        PageRequest pageable = PageRequest.of(Math.max(page, 0), boundedSize,
                Sort.by(Sort.Direction.DESC, "occurredAt").and(Sort.by(Sort.Direction.DESC, "createdAt")));
        Page<com.blistra.finance.domain.FinanceTransaction> result = transactionRepository.findAll(
                FinanceTransactionSpecifications.filters(user.getId(), accountId, categoryId, type, from, to,
                        amountMin, amountMax),
                pageable);
        return PageResponse.of(result, mapper::toTransactionResponse);
    }

    public TransactionResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        var transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        return mapper.toTransactionResponse(transaction);
    }

    @Transactional
    public TransactionResponse update(UUID id, TransactionRequest request) {
        User user = currentUserProvider.getCurrentUser();
        var transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        Account account = requireOwnedAccount(request.getAccountId(), user.getId());
        Category category = requireOwnedCategory(request.getCategoryId(), user.getId());
        BigDecimal amount = requirePositiveAmount(request.getAmount(), "amount");
        if (category.getType() != toCategoryType(request.getType())) {
            throw new BadRequestException(
                    "Transaction type does not match the category type ("
                            + category.getType().name().toLowerCase() + " category)");
        }
        transaction.setCategory(category);
        transaction.setType(request.getType());
        transaction.setAmount(amount);
        transaction.setCurrency(account.getCurrency());
        transaction.setOccurredAt(request.getOccurredAt() != null ? request.getOccurredAt() : transaction.getOccurredAt());
        transaction.setDescription(request.getDescription());
        transaction.setNotes(request.getNotes());
        return mapper.toTransactionResponse(transactionRepository.save(transaction));
    }

    @Transactional
    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        var transaction = transactionRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transaction not found"));
        transactionRepository.delete(transaction);
    }

    private Account requireOwnedAccount(UUID id, UUID userId) {
        Account account = accountRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        if (account.getStatus() == AccountStatus.ARCHIVED) {
            throw new BadRequestException("Cannot use an archived account");
        }
        return account;
    }

    private Category requireOwnedCategory(UUID id, UUID userId) {
        Category category = categoryRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        if (category.getStatus() == CategoryStatus.ARCHIVED) {
            throw new BadRequestException("Cannot use an archived category");
        }
        return category;
    }

    private com.blistra.finance.domain.CategoryType toCategoryType(com.blistra.finance.domain.TransactionType type) {
        return com.blistra.finance.domain.CategoryType.valueOf(type.name());
    }

    private BigDecimal requirePositiveAmount(String raw, String field) {
        BigDecimal amount = Money.parse(raw);
        if (amount.signum() <= 0) {
            throw new BadRequestException(field + " must be positive");
        }
        return amount;
    }
}