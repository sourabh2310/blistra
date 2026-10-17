package com.blistra.finance.dto;

/** A decimal-string amount in one currency. Signed where the field says so. */
public record CurrencyAmount(String currency, String amount) {
}
