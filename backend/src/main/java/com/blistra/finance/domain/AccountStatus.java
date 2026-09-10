package com.blistra.finance.domain;

/**
 * Lifecycle state of a finance account.
 *
 * <p>Deleting an account that holds financial history is unsafe, so accounts
 * are archived instead. Archived accounts remain intact for reporting but can
 * no longer be used as the target of new transactions or transfers.</p>
 */
public enum AccountStatus {
    ACTIVE,
    ARCHIVED
}