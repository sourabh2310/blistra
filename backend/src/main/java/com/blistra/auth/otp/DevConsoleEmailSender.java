package com.blistra.auth.otp;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Development-only email sender: prints the code to the console in a clearly
 * marked block. Active ONLY when {@code blistra.otp.dev-mode=true}.
 * Production uses a real provider implementation (see README/docs) and must
 * never log codes.
 */
@Slf4j
@Component
@ConditionalOnProperty(prefix = "blistra.otp", name = "dev-mode", havingValue = "true")
public class DevConsoleEmailSender implements EmailSender {

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        log.warn("[DEV ONLY] Email verification OTP generated. Account: {} OTP: {} (expires per blistra.otp.ttl-minutes)",
                mask(toEmail), code);
    }

    private static String mask(String email) {
        if (email == null || !email.contains("@")) {
            return "***";
        }
        String local = email.substring(0, email.indexOf('@'));
        String domain = email.substring(email.indexOf('@'));
        String shown = local.length() <= 2 ? local + "***" : local.substring(0, 2) + "***";
        return shown + domain;
    }
}
