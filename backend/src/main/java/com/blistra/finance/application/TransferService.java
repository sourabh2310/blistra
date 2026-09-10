package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.AccountStatus;
import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.PageResponse;
import com.blistra.finance.dto.TransferRequest;
import com.blistra.finance.dto.TransferResponse;
import com.blistra.finance.repository.AccountRepository;
import com.blistra.finance.repository.FinanceTransferRepository;
import com.blistra.finance.repository.FinanceTransferSpecifications;
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
public class TransferService {

    private static final int MAX_PAGE_SIZE = 100;

    private final FinanceTransferRepository transferRepository;
    private final AccountRepository accountRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FinanceMapper mapper;

    public TransferService(FinanceTransferRepository transferRepository,
                           AccountRepository accountRepository,
                           CurrentUserProvider currentUserProvider,
                           FinanceMapper mapper) {
        this.transferRepository = transferRepository;
        this.accountRepository = accountRepository;
        this.currentUserProvider = currentUserProvider;
        this.mapper = mapper;
    }

    @Transactional
    public TransferResponse create(TransferRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Account source = requireUsableAccount(request.getSourceAccountId(), user.getId());
        Account destination = requireUsableAccount(request.getDestinationAccountId(), user.getId());
        if (source.getId().equals(destination.getId())) {
            throw new BadRequestException("Source and destination account must be different");
        }
        if (!source.getCurrency().equals(destination.getCurrency())) {
            throw new BadRequestException(
                    "Transfer between accounts of different currencies is not supported");
        }
        BigDecimal amount = requirePositiveAmount(request.getAmount());
        LocalDate date = request.getTransferredAt() != null ? request.getTransferredAt() : LocalDate.now();
        var transfer = new com.blistra.finance.domain.FinanceTransfer(
                user, source, destination, amount, source.getCurrency(), date, request.getNote());
        return mapper.toTransferResponse(transferRepository.save(transfer));
    }

    public PageResponse<TransferResponse> list(UUID sourceAccountId, UUID destinationAccountId,
                                               LocalDate from, LocalDate to, int page, int size) {
        User user = currentUserProvider.getCurrentUser();
        if (sourceAccountId != null && !accountRepository.existsByIdAndUserId(sourceAccountId, user.getId())) {
            throw new ResourceNotFoundException("Account not found");
        }
        if (destinationAccountId != null && !accountRepository.existsByIdAndUserId(destinationAccountId, user.getId())) {
            throw new ResourceNotFoundException("Account not found");
        }
        int boundedSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        PageRequest pageable = PageRequest.of(Math.max(page, 0), boundedSize,
                Sort.by(Sort.Direction.DESC, "transferredAt").and(Sort.by(Sort.Direction.DESC, "createdAt")));
        Page<com.blistra.finance.domain.FinanceTransfer> result = transferRepository.findAll(
                FinanceTransferSpecifications.filters(user.getId(), sourceAccountId, destinationAccountId, from, to),
                pageable);
        return PageResponse.of(result, mapper::toTransferResponse);
    }

    public TransferResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        var transfer = transferRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transfer not found"));
        return mapper.toTransferResponse(transfer);
    }

    @Transactional
    public TransferResponse update(UUID id, TransferRequest request) {
        User user = currentUserProvider.getCurrentUser();
        var transfer = transferRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transfer not found"));
        Account source = requireUsableAccount(request.getSourceAccountId(), user.getId());
        Account destination = requireUsableAccount(request.getDestinationAccountId(), user.getId());
        if (source.getId().equals(destination.getId())) {
            throw new BadRequestException("Source and destination account must be different");
        }
        if (!source.getCurrency().equals(destination.getCurrency())) {
            throw new BadRequestException(
                    "Transfer between accounts of different currencies is not supported");
        }
        transfer.setAmount(requirePositiveAmount(request.getAmount()));
        transfer.setTransferredAt(request.getTransferredAt() != null
                ? request.getTransferredAt() : transfer.getTransferredAt());
        transfer.setNote(request.getNote());
        return mapper.toTransferResponse(transferRepository.save(transfer));
    }

    @Transactional
    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        var transfer = transferRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Transfer not found"));
        transferRepository.delete(transfer);
    }

    private Account requireUsableAccount(UUID id, UUID userId) {
        Account account = accountRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found"));
        if (account.getStatus() == AccountStatus.ARCHIVED) {
            throw new BadRequestException("Cannot use an archived account");
        }
        return account;
    }

    private BigDecimal requirePositiveAmount(String raw) {
        BigDecimal amount = Money.parse(raw);
        if (amount.signum() <= 0) {
            throw new BadRequestException("amount must be positive");
        }
        return amount;
    }
}