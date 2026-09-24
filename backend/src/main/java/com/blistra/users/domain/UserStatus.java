package com.blistra.users.domain;

public enum UserStatus {
    ACTIVE,
    INACTIVE,
    SUSPENDED,
    /**
     * Registered but has not finished the required email/phone verification.
     * May authenticate (to verify, complete onboarding and use the app), but
     * is not a fully active account yet.
     */
    PENDING_VERIFICATION
}
