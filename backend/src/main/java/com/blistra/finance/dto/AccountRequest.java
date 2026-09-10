package com.blistra.finance.dto;

import com.blistra.finance.domain.AccountType;
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

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AccountRequest {

    @NotBlank(message = "Account name is required")
    @Size(max = 100, message = "Account name must be at most 100 characters")
    private String name;

    @NotNull(message = "Account type is required")
    @Schema(description = "CASH, BANK, SAVINGS, CREDIT_CARD, WALLET or OTHER")
    private AccountType type;

    @NotBlank(message = "Currency is required")
    @Pattern(regexp = "^[A-Z]{3}$", message = "Currency must be a three-letter ISO 4217 code (for example USD)")
    @Schema(description = "ISO 4217 currency code, for example USD", example = "USD")
    private String currency;

    @NotBlank(message = "Opening balance is required")
    @Pattern(regexp = "^\\d+(\\.\\d+)?$", message = "Opening balance must be a non-negative decimal number")
    @Digits(integer = 15, fraction = 4, message = "Opening balance exceeds the supported range (up to 15 integer and 4 fraction digits)")
    @DecimalMin(value = "0", message = "Opening balance cannot be negative")
    @Schema(description = "Opening balance as a decimal string; must be non-negative for every account type "
            + "including CREDIT_CARD (V1 tracks asset-side balances; direction is never encoded in the sign)",
            example = "1000.0000")
    private String openingBalance;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;
}