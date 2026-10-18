package com.blistra.auth.otp;

import jakarta.annotation.PostConstruct;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code blistra.otp.*} tunables. Development mode selects console senders and
 * the dev OTP retrieval endpoint; production requires a pepper and uses
 * strictly hashed storage with no code logging.
 *
 * Registered via {@link OtpConfig}; no {@code @Component} here (it would
 * create a duplicate bean definition).
 */
@Data
@ConfigurationProperties(prefix = "blistra.otp")
public class OtpProperties {

    /** Local-development mode: console senders + dev OTP endpoint. Never true in prod. */
    private boolean devMode = false;

    /** Code validity in minutes (5-10 per spec; default 10). */
    private int ttlMinutes = 10;

    /** Wrong-code attempts before the code is invalidated. */
    private int maxAttempts = 5;

    /** Seconds before the same (user, purpose) code may be re-sent. */
    private long resendCooldownSeconds = 60;

    /** Max issuances per (user, purpose) per rolling hour (abuse cap). */
    private int maxPerHour = 10;

    /**
     * Server-side pepper mixed into the code hash. REQUIRED in production
     * (non-dev mode); dev falls back to a fixed non-secret value.
     */
    private String pepper;

    /** Durable provider delivery; development keeps its synchronous console flow. */
    private boolean outboxEnabled = false;

    /** Base64-encoded 32-byte AES key, separate from the verification pepper. */
    private String deliveryKey;

    @PostConstruct
    public void validate() {
        if (outboxEnabled) {
            try {
                if (java.util.Base64.getDecoder().decode(deliveryKey).length != 32) {
                    throw new IllegalArgumentException();
                }
            } catch (Exception e) {
                throw new IllegalStateException("OTP outbox requires a base64-encoded 32-byte delivery key");
            }
        }
        if (!devMode && (pepper == null || pepper.isBlank())) {
            throw new IllegalStateException(
                    "blistra.otp.pepper is required in production (non-dev OTP mode)");
        }
        if (ttlMinutes < 1 || ttlMinutes > 60) {
            throw new IllegalStateException("blistra.otp.ttl-minutes must be 1..60");
        }
    }

    public String effectivePepper() {
        if (pepper != null && !pepper.isBlank()) {
            return pepper;
        }
        return "dev-only-otp-pepper-not-for-production";
    }
}
