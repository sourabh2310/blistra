package com.blistra.common.exception;

/**
 * OTP check failed. The {@code code} distinguishes cases for the client
 * without leaking sensitive detail: INVALID_OTP, EXPIRED_OTP,
 * TOO_MANY_ATTEMPTS.
 */
public class OtpVerificationException extends RuntimeException {

    private final String code;

    public OtpVerificationException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
