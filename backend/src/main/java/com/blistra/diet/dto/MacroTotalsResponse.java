package com.blistra.diet.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Sum of one nutrition component for a set of meal items.
 *
 * <p>{@code total} is only computed from values that were explicitly recorded.
 * Missing values are excluded (never treated as zero); {@code total} is
 * {@code null} when no values were recorded. This is a calculation of recorded
 * data, not a recommendation or medical assessment.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class MacroTotalsResponse {

    private BigDecimal total;
    private long recordedItems;
}