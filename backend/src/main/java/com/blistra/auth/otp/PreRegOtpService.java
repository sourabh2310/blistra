package com.blistra.auth.otp;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Stateless, in-memory OTP service for pre-registration email verification.
 * Codes expire after 10 minutes and allow at most 5 attempts.
 * No persistence — entries survive only as long as the process is alive,
 * which is fine for the registration UX (users complete in a single session).
 */
@Slf4j
@Service
public class PreRegOtpService {

    private static final int TTL_SECONDS = 600;
    private static final int MAX_ATTEMPTS = 5;
    private static final long RESEND_COOLDOWN_SECONDS = 60;

    private record Entry(String codeHash, Instant expiresAt, Instant resendAllowedAt, int attempts, String devCode) {}

    private final Map<String, Entry> store = new ConcurrentHashMap<>();
    // Emails verified via pre-reg OTP — consumed (removed) on first register call.
    private final Set<String> verifiedEmails = ConcurrentHashMap.newKeySet();
    private final SecureRandom random = new SecureRandom();
    private final EmailSender emailSender;
    private final OtpProperties properties;

    public PreRegOtpService(EmailSender emailSender, OtpProperties properties) {
        this.emailSender = emailSender;
        this.properties = properties;
    }

    /** Sends an OTP to the given email. Returns the cooldown seconds for client UX. */
    public long send(String email) {
        String key = email.toLowerCase().trim();
        Entry existing = store.get(key);
        if (existing != null && Instant.now().isBefore(existing.resendAllowedAt())) {
            long wait = existing.resendAllowedAt().getEpochSecond() - Instant.now().getEpochSecond();
            return wait;
        }

        String code = String.format("%06d", random.nextInt(1000000));
        Instant now = Instant.now();
        Entry entry = new Entry(
                hash(code),
                now.plusSeconds(TTL_SECONDS),
                now.plusSeconds(RESEND_COOLDOWN_SECONDS),
                0,
                properties.isDevMode() ? code : null
        );
        store.put(key, entry);

        if (properties.isDevMode()) {
            log.warn("[DEV ONLY] Pre-reg email OTP. Email: {} OTP: {}", mask(email), code);
        }
        emailSender.sendVerificationCode(email, code);
        return RESEND_COOLDOWN_SECONDS;
    }

    /**
     * Verifies the code. Returns true on success.
     * Throws {@link IllegalStateException} with a message for the client on failure.
     */
    public boolean verify(String email, String code) {
        String key = email.toLowerCase().trim();
        Entry entry = store.get(key);
        if (entry == null || Instant.now().isAfter(entry.expiresAt())) {
            throw new IllegalStateException("OTP has expired or was never sent. Please request a new code.");
        }
        if (entry.attempts() >= MAX_ATTEMPTS) {
            throw new IllegalStateException("Too many incorrect attempts. Please request a new code.");
        }
        if (!entry.codeHash().equals(hash(code.trim()))) {
            store.put(key, new Entry(entry.codeHash(), entry.expiresAt(), entry.resendAllowedAt(), entry.attempts() + 1, entry.devCode()));
            throw new IllegalStateException("Incorrect code. Please try again.");
        }
        store.remove(key);
        verifiedEmails.add(key);
        return true;
    }

    /**
     * Returns true and removes the record if this email was pre-verified.
     * Called once during registration to skip the post-registration email OTP step.
     */
    public boolean consumeVerified(String email) {
        return verifiedEmails.remove(email.toLowerCase().trim());
    }

    private static String hash(String code) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(code.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static String mask(String email) {
        if (email == null || !email.contains("@")) return "***";
        String local = email.substring(0, email.indexOf('@'));
        String domain = email.substring(email.indexOf('@'));
        return (local.length() <= 2 ? local + "***" : local.substring(0, 2) + "***") + domain;
    }
}
