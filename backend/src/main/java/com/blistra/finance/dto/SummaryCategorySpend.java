package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record SummaryCategorySpend(
        @Schema(description = "Category id") java.util.UUID categoryId,
        String categoryName,
        @Schema(description = "Total spent in this category, as a decimal string") String amount
) {
}