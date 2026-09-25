package com.blistra.auth.otp;

import com.blistra.common.exception.VerificationUnavailableException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Production fallback when no real SMS provider is configured
 * (dev-mode=false). Fails closed with 503 so verification is never silently
 * faked; wire a real provider implementation for production.
 */
@Component
@ConditionalOnProperty(prefix = "blistra.otp", name = "dev-mode", havingValue = "false", matchIfMissing = true)
public class NoOpSmsSender implements SmsSender {

    @Override
    public void sendVerificationCode(String toPhone, String code) {
        throw new VerificationUnavailableException(
                "SMS verification is not configured. Please try again later.");
    }
}
