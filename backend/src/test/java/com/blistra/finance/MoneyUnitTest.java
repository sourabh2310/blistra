package com.blistra.finance;

import com.blistra.common.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Unit tests for exact monetary arithmetic and parsing.
 */
class MoneyUnitTest {

    @Test
    void parsesAndNormalizesToFixedScale() {
        assertThat(com.blistra.finance.domain.Money.parse("0.0001"))
                .isEqualByComparingTo("0.0001");
        assertThat(com.blistra.finance.domain.Money.parse("10"))
                .isEqualByComparingTo("10.0000");
        assertThat(com.blistra.finance.domain.Money.parse("1.2"))
                .isEqualByComparingTo("1.2000");
    }

    @Test
    void rendersPlainStringAtFixedScale() {
        assertThat(com.blistra.finance.domain.Money.toPlainString(new BigDecimal("42.5")))
                .isEqualTo("42.5000");
        assertThat(com.blistra.finance.domain.Money.toPlainString(new BigDecimal("0")))
                .isEqualTo("0.0000");
    }

    @Test
    void rejectsFractionBeyondPrecision() {
        assertThatThrownBy(() -> com.blistra.finance.domain.Money.parse("1.00001"))
                .isInstanceOf(BadRequestException.class)
                .hasMessage("Invalid monetary amount");
    }

    @Test
    void rejectsNonNumeric() {
        assertThatThrownBy(() -> com.blistra.finance.domain.Money.parse("abc"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void currencyCodeValidation() {
        assertThat(com.blistra.finance.domain.Money.isCurrencyCode("USD")).isTrue();
        assertThat(com.blistra.finance.domain.Money.isCurrencyCode("usd")).isFalse();
        assertThat(com.blistra.finance.domain.Money.isCurrencyCode("US  ")).isFalse();
        assertThat(com.blistra.finance.domain.Money.isCurrencyCode(null)).isFalse();
    }
}