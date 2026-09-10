package com.blistra.finance.dto;

import com.blistra.finance.domain.CategoryType;
import com.blistra.finance.domain.CategoryStatus;
import io.swagger.v3.oas.annotations.media.Schema;

public record CategoryResponse(
        @Schema(description = "Category id as lower-case UUID")
        java.util.UUID id,

        String name,

        @Schema(description = "INCOME or EXPENSE")
        CategoryType type,

        @Schema(description = "ACTIVE or ARCHIVED")
        CategoryStatus status,

        @Schema(description = "Creation timestamp, ISO 8601 UTC")
        String createdAt,

        @Schema(description = "Last update timestamp, ISO 8601 UTC")
        String updatedAt
) {
}