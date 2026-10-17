package com.blistra.finance.dto;

import com.blistra.finance.domain.ExpenseCategory;
import com.blistra.finance.domain.SplitType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record ExpenseRequest(
        @NotBlank @Size(max = 255) String description,
        @NotNull ExpenseCategory category,
        @NotBlank @Schema(description = "Positive decimal string") String amount,
        @NotBlank @Pattern(regexp = "^[A-Z]{3}$", message = "must be a 3-letter currency code") String currency,
        @Schema(description = "Defaults to today") LocalDate spentOn,
        @Size(max = 1000) String notes,
        @Schema(description = "Who paid; defaults to you") UUID paidBy,
        @Schema(description = "Defaults to NONE without participants, EQUAL with them") SplitType splitType,
        @Schema(description = "People sharing the cost (include yourself if you share it)")
        List<@Valid ParticipantInput> participants
) {
}
