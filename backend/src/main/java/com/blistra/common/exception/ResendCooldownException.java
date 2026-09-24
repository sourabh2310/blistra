package com.blistra.common.exception;

/** Resend requested before the cooldown elapsed (429 with retry hint). */
public class ResendCooldownException extends RuntimeException {

    private final long retryAfterSeconds;

    public ResendCooldownException(long retryAfterSeconds) {
        super("Please wait before requesting another code.");
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public long getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
