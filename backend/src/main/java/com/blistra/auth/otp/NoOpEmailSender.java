package com.blistra.auth.otp;

import com.blistra.common.exception.VerificationUnavailableException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/**
 * Production fallback when no real email provider is configured
 * (dev-mode=false). Fails closed with 503 so verification is never silently
 * faked; wire a real provider implementation for production.
 */
@Component
@ConditionalOnExpression("'${blistra.otp.dev-mode:false}' != 'true' and '${blistra.mail.enabled:false}' != 'true'")
public class NoOpEmailSender implements EmailSender {

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        throw new VerificationUnavailableException(
                "Email verification is not configured. Please try again later.");
    }
}
