package com.blistra.finance.domain;

/**
 * The financial direction a category represents.
 *
 * <p>Categories only classify income or expense transactions (never
 * transfers, which are a separate domain concept).</p>
 */
public enum CategoryType {
    INCOME,
    EXPENSE
}