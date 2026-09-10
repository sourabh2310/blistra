package com.blistra.finance.domain;

/**
 * The direction of a transaction.
 *
 * <p>Direction is expressed by the type rather than by the sign of the amount;
 * every stored amount is positive. This avoids ambiguous sign conventions.</p>
 */
public enum TransactionType {
    INCOME,
    EXPENSE
}