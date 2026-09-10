package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.AccountStatus;
import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.AccountRequest;
import com.blistra.finance.dto.AccountResponse;
import com.blistra.finance.repository.AccountRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class AccountService {

    private final AccountRepository accountRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FinanceMapper mapper;
    private final BalanceCalculator balanceCalculator;

    public AccountService(AccountRepository accountRepository,
                          CurrentUserProvider currentUserProvider,
                          FinanceMapper mapper,
                          BalanceCalculator balanceCalculator) {
        this.accountRepository = accountRepository;
        this.currentUserProvider = currentUserProvider;
        this.mapper = mapper;
        this.balanceCalculator = balanceCalculator;
    }

    @Transactional
    public AccountResponse create(AccountRequest request) {
        User user = currentUserProvider.getCurrentUser();
        String currency = request.getCurrency().toUpperCase();
        if (!Money.isCurrencyCode(currency)) {
            throw new BadRequestException("Currency must be a three-letter ISO 4217 code");
        }
        Account account = new Account(user, request.getName(), request.getType(), currency,
                Money.parse(request.getOpeningBalance()), AccountStatus.ACTIVE, request.getNotes());
        Account saved = accountRepository.save(account);
        return mapper.toAccountResponse(saved, Money.toPlainString(saved.getOpeningBalance()));
    }

    public List<AccountResponse> list() {
        User user = currentUserProvider.getCurrentUser();
        List<Account> accounts = accountRepository
                .findAllByUserIdOrderByCreatedAtAsc(user.getId());
        if (accounts.isEmpty()) {
            return java.util.List.of();
        }
        var balances = balanceCalculator.balancesFor(user.getId());
        return accounts.stream()
                .map(account -> mapper.toAccountResponse(account,
                        Money.toPlainString(account.getOpeningBalance()
                                .add(balances.getOrDefault(account.getId(), BigDecimal.ZERO))
                                .setScale(Money.SCALE, java.math.RoundingMode.UNNECESSARY))))
                .toList();
    }

    public AccountResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        Account account = accountRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        return mapper.toAccountResponse(account,
                Money.toPlainString(balanceCalculator.balanceFor(account)));
    }

    @Transactional
    public AccountResponse update(UUID id, AccountRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Account account = accountRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        if (account.getStatus() == AccountStatus.ARCHIVED) {
            throw new BadRequestException("Cannot update an archived account");
        }
        String currency = request.getCurrency().toUpperCase();
        if (!Money.isCurrencyCode(currency)) {
            throw new BadRequestException("Currency must be a three-letter ISO 4217 code");
        }
        if (!account.getCurrency().equals(currency)) {
            throw new BadRequestException("Account currency cannot be changed");
        }
        account.setName(request.getName());
        account.setType(request.getType());
        account.setOpeningBalance(Money.parse(request.getOpeningBalance()));
        account.setNotes(request.getNotes());
        Account saved = accountRepository.save(account);
        return mapper.toAccountResponse(saved,
                Money.toPlainString(balanceCalculator.balanceFor(saved)));
    }

    @Transactional
    public void archive(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        Account account = accountRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        if (account.getStatus() == AccountStatus.ARCHIVED) {
            throw new BadRequestException("Account is already archived");
        }
        account.setStatus(AccountStatus.ARCHIVED);
        accountRepository.save(account);
    }
}