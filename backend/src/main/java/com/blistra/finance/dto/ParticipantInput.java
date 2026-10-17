package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record ParticipantInput(
        @NotNull UUID userId,
        @Schema(description = "Amount (EXACT), percentage (PERCENT) or weight (SHARES); ignored for EQUAL")
        String value
) {
}
