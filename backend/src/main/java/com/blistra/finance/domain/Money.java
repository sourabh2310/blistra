package com.blistra.finance.domain;

import com.blistra.common.exception.BadRequestException;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Financial money helpers.
 *
 * <p>All monetary values are stored as {@link BigDecimal} with scale 4
 * (NUMERIC(19,4) in PostgreSQL). Amounts are always normalized to that scale so
 * arithmetic is exact and predictable. Floating-point types are never used for
 * money.</p>
 */
public final class Money {

    public static final int SCALE = 4;

    private Money() {
    }

    /**
     * Parses a client-supplied decimal string and normalizes it to the fixed
     * financial scale. Rejects anything that could not round-trip exactly.
     */
    public static BigDecimal parse(String raw) {
        try {
            return new BigDecimal(raw).setScale(SCALE, RoundingMode.UNNECESSARY);
        } catch (NumberFormatException | ArithmeticException ex) {
            throw new BadRequestException("Invalid monetary amount");
        }
    }

    /**
     * Renders a monetary value as a plain decimal string (no exponent), always
     * at the fixed financial scale.
     */
    public static String toPlainString(BigDecimal value) {
        return value.setScale(SCALE, RoundingMode.UNNECESSARY).toPlainString();
    }

    /**
     * Validates an ISO 4217 style currency code (three uppercase letters).
     */
    public static boolean isCurrencyCode(String code) {
        return code != null && code.matches("^[A-Z]{3}$");
    }
}