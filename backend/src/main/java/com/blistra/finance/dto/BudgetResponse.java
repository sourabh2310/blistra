package com.blistra.finance.dto;

import com.blistra.finance.domain.ExpenseCategory;

import java.util.UUID;

public record BudgetResponse(UUID id, ExpenseCategory category, String currency, String monthlyLimit,
                             String spentThisMonth) {
}
