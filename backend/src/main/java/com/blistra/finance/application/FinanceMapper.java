package com.blistra.finance.application;

import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.Category;
import com.blistra.finance.domain.FinanceTransaction;
import com.blistra.finance.domain.FinanceTransfer;
import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.AccountResponse;
import com.blistra.finance.dto.CategoryResponse;
import com.blistra.finance.dto.TransactionResponse;
import com.blistra.finance.dto.TransferResponse;
import org.springframework.stereotype.Component;

import java.time.format.DateTimeFormatter;

/**
 * Maps finance domain entities into API response DTOs.
 *
 * <p>Monetary values travel as plain decimal strings at the fixed financial
 * scale so exact precision survives JSON transport.</p>
 */
@Component
public class FinanceMapper {

    private static final DateTimeFormatter ISO_DATE = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final DateTimeFormatter ISO_DATE_TIME = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private String fmtDateTime(java.time.LocalDateTime value) {
        return value.format(ISO_DATE_TIME);
    }

    private String fmtDate(java.time.LocalDate value) {
        return value.format(ISO_DATE);
    }

    public AccountResponse toAccountResponse(Account account, String derivedBalance) {
        return new AccountResponse(
                account.getId(),
                account.getName(),
                account.getType(),
                account.getCurrency(),
                Money.toPlainString(account.getOpeningBalance()),
                derivedBalance,
                account.getStatus(),
                account.getNotes(),
                fmtDateTime(account.getCreatedAt()),
                fmtDateTime(account.getUpdatedAt())
        );
    }

    public CategoryResponse toCategoryResponse(Category category) {
        return new CategoryResponse(
                category.getId(),
                category.getName(),
                category.getType(),
                category.getStatus(),
                fmtDateTime(category.getCreatedAt()),
                fmtDateTime(category.getUpdatedAt())
        );
    }

    public TransactionResponse toTransactionResponse(FinanceTransaction transaction) {
        return new TransactionResponse(
                transaction.getId(),
                transaction.getAccount().getId(),
                transaction.getAccount().getName(),
                transaction.getAccount().getCurrency(),
                transaction.getCategory().getId(),
                transaction.getCategory().getName(),
                transaction.getType(),
                Money.toPlainString(transaction.getAmount()),
                transaction.getCurrency(),
                fmtDate(transaction.getOccurredAt()),
                transaction.getDescription(),
                transaction.getNotes(),
                fmtDateTime(transaction.getCreatedAt()),
                fmtDateTime(transaction.getUpdatedAt())
        );
    }

    public TransferResponse toTransferResponse(FinanceTransfer transfer) {
        return new TransferResponse(
                transfer.getId(),
                transfer.getSourceAccount().getId(),
                transfer.getSourceAccount().getName(),
                transfer.getDestinationAccount().getId(),
                transfer.getDestinationAccount().getName(),
                Money.toPlainString(transfer.getAmount()),
                transfer.getCurrency(),
                fmtDate(transfer.getTransferredAt()),
                transfer.getNote(),
                fmtDateTime(transfer.getCreatedAt()),
                fmtDateTime(transfer.getUpdatedAt())
        );
    }
}