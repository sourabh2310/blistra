package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.SplitType;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Divides an expense amount between participants.
 *
 * <p>Results are rounded to whole cents and always sum exactly to the
 * amount: leftover cents from rounding go to the first participants in the
 * given order, so the split is deterministic.</p>
 */
public final class SplitCalculator {

    private static final int CENTS = 2;
    private static final BigDecimal HUNDRED = new BigDecimal("100");

    /** One participant as entered: {@code value} is ignored for EQUAL. */
    public record Input(UUID userId, BigDecimal value) {
    }

    /** One computed share; {@code inputValue} keeps the percent/weight entered. */
    public record Share(UUID userId, BigDecimal amount, BigDecimal inputValue) {
    }

    private SplitCalculator() {
    }

    public static List<Share> split(BigDecimal amount, SplitType type, List<Input> inputs) {
        if (inputs.isEmpty()) {
            throw new BadRequestException("Add at least one person to split with");
        }
        Set<UUID> seen = new LinkedHashSet<>();
        for (Input input : inputs) {
            if (!seen.add(input.userId())) {
                throw new BadRequestException("Each person can appear only once in a split");
            }
        }
        return switch (type) {
            case NONE, EQUAL -> weighted(amount, inputs, inputs.stream().map(i -> BigDecimal.ONE).toList(), false);
            case EXACT -> exact(amount, inputs);
            case PERCENT -> percent(amount, inputs);
            case SHARES -> {
                List<BigDecimal> weights = inputs.stream().map(i -> requireValue(i, "share")).toList();
                if (weights.stream().anyMatch(w -> w.signum() < 0)) {
                    throw new BadRequestException("Shares cannot be negative");
                }
                if (weights.stream().allMatch(w -> w.signum() == 0)) {
                    throw new BadRequestException("At least one person needs a share above zero");
                }
                yield weighted(amount, inputs, weights, true);
            }
        };
    }

    private static List<Share> exact(BigDecimal amount, List<Input> inputs) {
        List<Share> shares = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Input input : inputs) {
            BigDecimal value = requireValue(input, "amount");
            if (value.signum() < 0) {
                throw new BadRequestException("Split amounts cannot be negative");
            }
            BigDecimal normalized = value.setScale(Money.SCALE, RoundingMode.HALF_UP);
            total = total.add(normalized);
            shares.add(new Share(input.userId(), normalized, null));
        }
        if (total.compareTo(amount) != 0) {
            throw new BadRequestException("Split amounts add up to " + total.stripTrailingZeros().toPlainString()
                    + " but the expense is " + amount.stripTrailingZeros().toPlainString());
        }
        return shares;
    }

    private static List<Share> percent(BigDecimal amount, List<Input> inputs) {
        List<BigDecimal> percents = inputs.stream().map(i -> requireValue(i, "percentage")).toList();
        BigDecimal total = BigDecimal.ZERO;
        for (BigDecimal p : percents) {
            if (p.signum() < 0) {
                throw new BadRequestException("Percentages cannot be negative");
            }
            total = total.add(p);
        }
        if (total.compareTo(HUNDRED) != 0) {
            throw new BadRequestException("Percentages must add up to 100 (currently "
                    + total.stripTrailingZeros().toPlainString() + ")");
        }
        return weighted(amount, inputs, percents, true);
    }

    /**
     * Splits proportionally to {@code weights} in whole cents, handing the
     * leftover cents to the first participants with a non-zero weight.
     */
    private static List<Share> weighted(BigDecimal amount, List<Input> inputs, List<BigDecimal> weights,
                                        boolean keepInput) {
        BigDecimal totalWeight = weights.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        long totalCents = amount.movePointRight(CENTS).setScale(0, RoundingMode.DOWN).longValueExact();
        long[] cents = new long[inputs.size()];
        long allocated = 0;
        for (int i = 0; i < inputs.size(); i++) {
            cents[i] = BigDecimal.valueOf(totalCents).multiply(weights.get(i))
                    .divide(totalWeight, 0, RoundingMode.DOWN).longValueExact();
            allocated += cents[i];
        }
        long leftover = totalCents - allocated;
        for (int i = 0; leftover > 0; i = (i + 1) % inputs.size()) {
            if (weights.get(i).signum() > 0) {
                cents[i]++;
                leftover--;
            }
        }
        // Sub-cent amounts (e.g. 10.0050) keep their remainder on the first share.
        BigDecimal subCent = amount.subtract(BigDecimal.valueOf(totalCents).movePointLeft(CENTS));
        List<Share> shares = new ArrayList<>();
        for (int i = 0; i < inputs.size(); i++) {
            BigDecimal share = BigDecimal.valueOf(cents[i]).movePointLeft(CENTS);
            if (i == 0) {
                share = share.add(subCent);
            }
            shares.add(new Share(inputs.get(i).userId(), share.setScale(Money.SCALE, RoundingMode.UNNECESSARY),
                    keepInput ? weights.get(i).setScale(Money.SCALE, RoundingMode.HALF_UP) : null));
        }
        return shares;
    }

    private static BigDecimal requireValue(Input input, String what) {
        if (input.value() == null) {
            throw new BadRequestException("Enter a " + what + " for every person in the split");
        }
        return input.value();
    }
}
