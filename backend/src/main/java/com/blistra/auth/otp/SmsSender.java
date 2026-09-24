package com.blistra.auth.otp;

/**
 * Vendor-neutral SMS delivery for verification codes. The auth domain depends
 * only on this interface; gateway wiring lives in an implementation.
 */
public interface SmsSender {

    /**
     * Sends a verification code to {@code toPhone} (E.164).
     *
     * @throws com.blistra.common.exception.VerificationUnavailableException
     *         when no provider is configured
     */
    void sendVerificationCode(String toPhone, String code);
}
