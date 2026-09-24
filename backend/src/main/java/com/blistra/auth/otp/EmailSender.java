package com.blistra.auth.otp;

/**
 * Vendor-neutral email delivery for verification codes. The auth domain
 * depends only on this interface; SMTP/provider wiring lives in an
 * implementation (see DevConsoleEmailSender for local development).
 */
public interface EmailSender {

    /**
     * Sends a verification code to {@code toEmail}.
     *
     * @throws com.blistra.common.exception.VerificationUnavailableException
     *         when no provider is configured
     */
    void sendVerificationCode(String toEmail, String code);
}
