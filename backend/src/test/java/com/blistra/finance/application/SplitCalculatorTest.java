package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.finance.domain.SplitType;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SplitCalculatorTest {

    private final UUID a = UUID.randomUUID();
    private final UUID b = UUID.randomUUID();
    private final UUID c = UUID.randomUUID();

    private static SplitCalculator.Input in(UUID id, String value) {
        return new SplitCalculator.Input(id, value == null ? null : new BigDecimal(value));
    }

    private static List<String> amounts(List<SplitCalculator.Share> shares) {
        return shares.stream().map(s -> s.amount().toPlainString()).toList();
    }

    @Test
    void equalSplitGivesLeftoverCentsToFirstParticipants() {
        var shares = SplitCalculator.split(new BigDecimal("100.0000"), SplitType.EQUAL,
                List.of(in(a, null), in(b, null), in(c, null)));
        assertThat(amounts(shares)).containsExactly("33.3400", "33.3300", "33.3300");
    }

    @Test
    void sharesAlwaysSumToTheAmountIncludingSubCentRemainders() {
        var shares = SplitCalculator.split(new BigDecimal("10.0050"), SplitType.EQUAL,
                List.of(in(a, null), in(b, null), in(c, null)));
        BigDecimal total = shares.stream().map(SplitCalculator.Share::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertThat(total).isEqualByComparingTo("10.0050");
        assertThat(shares).allMatch(s -> s.amount().signum() >= 0);
    }

    @Test
    void exactSplitMustMatchTheTotal() {
        var shares = SplitCalculator.split(new BigDecimal("50.0000"), SplitType.EXACT,
                List.of(in(a, "20"), in(b, "30")));
        assertThat(amounts(shares)).containsExactly("20.0000", "30.0000");

        assertThatThrownBy(() -> SplitCalculator.split(new BigDecimal("50.0000"), SplitType.EXACT,
                List.of(in(a, "20"), in(b, "20"))))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("add up to 40");
    }

    @Test
    void percentSplitMustTotalHundredAndKeepsInput() {
        var shares = SplitCalculator.split(new BigDecimal("200.0000"), SplitType.PERCENT,
                List.of(in(a, "25"), in(b, "75")));
        assertThat(amounts(shares)).containsExactly("50.0000", "150.0000");
        assertThat(shares.get(0).inputValue()).isEqualByComparingTo("25");

        assertThatThrownBy(() -> SplitCalculator.split(new BigDecimal("200.0000"), SplitType.PERCENT,
                List.of(in(a, "25"), in(b, "70"))))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void sharesSplitIsProportionalAndSkipsZeroWeightsForLeftovers() {
        var shares = SplitCalculator.split(new BigDecimal("10.0000"), SplitType.SHARES,
                List.of(in(a, "0"), in(b, "1"), in(c, "2")));
        assertThat(amounts(shares)).containsExactly("0.0000", "3.3400", "6.6600");
    }

    @Test
    void rejectsDuplicatesMissingValuesAndNegativeValues() {
        assertThatThrownBy(() -> SplitCalculator.split(BigDecimal.TEN, SplitType.EQUAL,
                List.of(in(a, null), in(a, null)))).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> SplitCalculator.split(BigDecimal.TEN, SplitType.EXACT,
                List.of(in(a, null), in(b, "10")))).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> SplitCalculator.split(BigDecimal.TEN, SplitType.SHARES,
                List.of(in(a, "-1"), in(b, "2")))).isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> SplitCalculator.split(BigDecimal.TEN, SplitType.EQUAL, List.of()))
                .isInstanceOf(BadRequestException.class);
    }
}
