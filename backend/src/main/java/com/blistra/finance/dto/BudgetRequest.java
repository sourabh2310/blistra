package com.blistra.finance.dto;

import com.blistra.finance.domain.ExpenseCategory;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record BudgetRequest(
        @Schema(description = "Null for the overall monthly budget") ExpenseCategory category,
        @NotBlank @Pattern(regexp = "^[A-Z]{3}$", message = "must be a 3-letter currency code") String currency,
        @NotBlank String monthlyLimit
) {
}
