package com.blistra.finance.domain;

/**
 * Lifecycle state of a finance category.
 *
 * <p>Categories may be referenced by historical transactions, so they are
 * archived rather than deleted. Archived categories can no longer be selected
 * for new transactions but remain resolvable for history.</p>
 */
public enum CategoryStatus {
    ACTIVE,
    ARCHIVED
}