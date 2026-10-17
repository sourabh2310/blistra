package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.UUID;

public record SettlementRequest(
        @NotNull UUID friendId,
        @NotNull @Schema(description = "I_PAID: you paid them back; THEY_PAID: they paid you back")
        Direction direction,
        @NotBlank String amount,
        @NotBlank @Pattern(regexp = "^[A-Z]{3}$", message = "must be a 3-letter currency code") String currency,
        LocalDate settledOn,
        @Size(max = 255) String note
) {
    public enum Direction { I_PAID, THEY_PAID }
}
