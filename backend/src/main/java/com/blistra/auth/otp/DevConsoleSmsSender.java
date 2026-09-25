package com.blistra.auth.otp;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Development-only SMS sender: prints the code to the console in a clearly
 * marked block. Active ONLY when {@code blistra.otp.dev-mode=true}.
 */
@Slf4j
@Component
@ConditionalOnProperty(prefix = "blistra.otp", name = "dev-mode", havingValue = "true")
public class DevConsoleSmsSender implements SmsSender {

    @Override
    public void sendVerificationCode(String toPhone, String code) {
        log.warn("[DEV ONLY] SMS verification OTP generated. Phone: {} OTP: {} (expires per blistra.otp.ttl-minutes)",
                mask(toPhone), code);
    }

    private static String mask(String phone) {
        if (phone == null || phone.length() < 4) {
            return "***";
        }
        return "***" + phone.substring(phone.length() - 2);
    }
}
