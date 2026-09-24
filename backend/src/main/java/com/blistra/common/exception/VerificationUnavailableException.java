package com.blistra.common.exception;

/** No delivery provider is configured for the requested channel (503). */
public class VerificationUnavailableException extends RuntimeException {
    public VerificationUnavailableException(String message) {
        super(message);
    }
}
