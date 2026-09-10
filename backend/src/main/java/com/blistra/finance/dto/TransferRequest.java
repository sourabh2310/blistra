package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TransferRequest {

    @NotNull(message = "Source account id is required")
    private java.util.UUID sourceAccountId;

    @NotNull(message = "Destination account id is required")
    private java.util.UUID destinationAccountId;

    @NotBlank(message = "Amount is required")
    @Pattern(regexp = "^\\d+(\\.\\d+)?$", message = "Amount must be a non-negative decimal number")
    @Digits(integer = 15, fraction = 4, message = "Amount exceeds the supported range (up to 15 integer and 4 fraction digits)")
    @DecimalMin(value = "0.0001", message = "Amount must be positive")
    @Schema(description = "Amount as a decimal string", example = "150.0000")
    private String amount;

    @Schema(description = "Business date of the transfer, defaults to today when omitted",
            example = "2026-09-10")
    private LocalDate transferredAt;

    @Size(max = 1000, message = "Note must be at most 1000 characters")
    private String note;
}