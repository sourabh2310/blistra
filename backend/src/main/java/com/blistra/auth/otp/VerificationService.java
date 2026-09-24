package com.blistra.auth.otp;

import com.blistra.common.exception.OtpVerificationException;
import com.blistra.common.exception.ResendCooldownException;
import com.blistra.common.exception.TooManyRequestsException;
import com.blistra.users.domain.User;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Issues and checks 6-digit verification codes.
 *
 * <ul>
 *   <li>Codes are random (SecureRandom), short-lived and single-use.</li>
 *   <li>Only a SHA-256 hash (code + server pepper) is stored; plaintext is
 *       never persisted except the dev-only {@code devCode} copy.</li>
 *   <li>Attempt counting, resend cooldown and hourly caps are enforced here,
 *       so every caller (registration, recovery, identity change) inherits
 *       the same abuse protection.</li>
 *   <li>Codes themselves are never logged; destinations are masked.</li>
 * </ul>
 */
@Slf4j
@Service
public class VerificationService {

    private final VerificationOtpRepository otpRepository;
    private final EmailSender emailSender;
    private final SmsSender smsSender;
    private final OtpProperties properties;
    private final TransactionTemplate requiresNew;
    private final SecureRandom random = new SecureRandom();

    public VerificationService(VerificationOtpRepository otpRepository,
                               EmailSender emailSender,
                               SmsSender smsSender,
                               OtpProperties properties,
                               PlatformTransactionManager transactionManager) {
        this.otpRepository = otpRepository;
        this.emailSender = emailSender;
        this.smsSender = smsSender;
        this.properties = properties;
        this.requiresNew = new TransactionTemplate(transactionManager);
        this.requiresNew.setPropagationBehavior(
                org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    /** Result of issuing a code: expiry + cooldown for client UX. */
    public record Issuance(LocalDateTime expiresAt, long cooldownSeconds) {
    }

    /**
     * Issues a fresh code for (user, purpose), superseding older active ones,
     * and delivers it on {@code channel} to {@code destination}.
     */
    @Transactional
    public Issuance issue(UUID userId, OtpPurpose purpose, OtpChannel channel, String destination) {
        enforceHourlyCap(userId, purpose);
        enforceCooldown(userId, purpose);

        String code = String.format("%06d", random.nextInt(1000000));
        VerificationOtp otp = new VerificationOtp();
        otp.setUserId(userId);
        otp.setPurpose(purpose);
        otp.setChannel(channel);
        otp.setDestination(destination);
        otp.setCodeHash(hash(code));
        otp.setMaxAttempts(properties.getMaxAttempts());
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(properties.getTtlMinutes()));
        if (properties.isDevMode()) {
            otp.setDevCode(code);
        }

        // Supersede older active codes for the same purpose so only the
        // newest code verifies (old codes fail closed as invalid).
        List<VerificationOtp> prior =
                otpRepository.findByUserIdAndPurposeAndConsumedFalseOrderByCreatedAtDesc(userId, purpose);
        for (VerificationOtp old : prior) {
            old.setConsumed(true);
            old.setConsumedAt(LocalDateTime.now());
        }
        otpRepository.save(otp);

        deliver(channel, destination, code);
        log.info("OTP issued purpose={} channel={} destination={}", purpose, channel, mask(destination));
        return new Issuance(otp.getExpiresAt(), properties.getResendCooldownSeconds());
    }

    /**
     * Checks {@code code} against the latest active record. Consumes it on
     * success. Throws {@link OtpVerificationException} with INVALID_OTP,
     * EXPIRED_OTP or TOO_MANY_ATTEMPTS.
     *
     * <p>State changes commit in an isolated transaction BEFORE the outcome is
     * reported: a thrown verification failure must not roll back attempt
     * counting or consumption (otherwise brute force would never lock out and
     * used codes could verify twice on partial failures).
     */
    public VerificationOtp verify(UUID userId, OtpPurpose purpose, String code) {
        Outcome outcome = requiresNew.execute(status -> check(userId, purpose, code));
        if (outcome == null || outcome.errorCode != null) {
            String errorCode = outcome == null ? "INVALID_OTP" : outcome.errorCode;
            String message = outcome == null ? "Invalid or expired code." : outcome.message;
            throw new OtpVerificationException(errorCode, message);
        }
        return outcome.otp;
    }

    private record Outcome(VerificationOtp otp, String errorCode, String message) {
        static Outcome ok(VerificationOtp otp) {
            return new Outcome(otp, null, null);
        }

        static Outcome fail(String errorCode, String message) {
            return new Outcome(null, errorCode, message);
        }
    }

    private Outcome check(UUID userId, OtpPurpose purpose, String code) {
        Optional<VerificationOtp> latest = otpRepository.findLatestActive(userId, purpose);
        if (latest.isEmpty()) {
            return Outcome.fail("INVALID_OTP", "Invalid or expired code.");
        }
        VerificationOtp otp = latest.get();
        if (otp.isExpired()) {
            otp.setConsumed(true);
            otp.setConsumedAt(LocalDateTime.now());
            otpRepository.save(otp);
            return Outcome.fail("EXPIRED_OTP", "This code has expired. Request a new one.");
        }
        if (otp.getAttempts() >= otp.getMaxAttempts()) {
            otp.setConsumed(true);
            otp.setConsumedAt(LocalDateTime.now());
            otpRepository.save(otp);
            return Outcome.fail("TOO_MANY_ATTEMPTS",
                    "Too many incorrect attempts. Request a new code.");
        }
        if (code == null || !hash(code.trim()).equals(otp.getCodeHash())) {
            otp.setAttempts(otp.getAttempts() + 1);
            if (otp.getAttempts() >= otp.getMaxAttempts()) {
                otp.setConsumed(true);
                otp.setConsumedAt(LocalDateTime.now());
                otpRepository.save(otp);
                return Outcome.fail("TOO_MANY_ATTEMPTS",
                        "Too many incorrect attempts. Request a new code.");
            }
            otpRepository.save(otp);
            int remaining = otp.getMaxAttempts() - otp.getAttempts();
            return Outcome.fail("INVALID_OTP",
                    "Incorrect code. " + remaining + " attempt(s) remaining.");
        }
        otp.setConsumed(true);
        otp.setConsumedAt(LocalDateTime.now());
        otpRepository.save(otp);
        return Outcome.ok(otp);
    }

    /** Seconds until a resend is allowed; 0 when no cooldown applies. */
    @Transactional(readOnly = true)
    public long resendCooldownRemaining(UUID userId, OtpPurpose purpose) {
        Optional<VerificationOtp> latest = otpRepository.findLatestActive(userId, purpose);
        if (latest.isEmpty()) {
            return 0;
        }
        // Cooldown runs from the newest issuance regardless of consumption:
        // check all recent rows for the purpose.
        List<VerificationOtp> recent =
                otpRepository.findByUserIdAndPurposeAndConsumedFalseOrderByCreatedAtDesc(userId, purpose);
        if (recent.isEmpty()) {
            return 0;
        }
        LocalDateTime nextAllowed =
                recent.get(0).getCreatedAt().plusSeconds(properties.getResendCooldownSeconds());
        long remaining = java.time.Duration.between(LocalDateTime.now(), nextAllowed).getSeconds();
        return Math.max(0, remaining);
    }

    /** Latest usable record for dev retrieval; empty when none. */
    @Transactional(readOnly = true)
    public Optional<VerificationOtp> latestActive(UUID userId, OtpPurpose purpose) {
        return otpRepository.findLatestActive(userId, purpose).filter(o -> !o.isExpired());
    }

    private void enforceCooldown(UUID userId, OtpPurpose purpose) {
        long remaining = resendCooldownRemaining(userId, purpose);
        if (remaining > 0) {
            throw new ResendCooldownException(remaining);
        }
    }

    private void enforceHourlyCap(UUID userId, OtpPurpose purpose) {
        long sent = otpRepository.countByUserIdAndPurposeAndCreatedAtAfter(
                userId, purpose, LocalDateTime.now().minusHours(1));
        if (sent >= properties.getMaxPerHour()) {
            throw new TooManyRequestsException("Too many codes sent. Please try again later.");
        }
    }

    private void deliver(OtpChannel channel, String destination, String code) {
        if (channel == OtpChannel.EMAIL) {
            emailSender.sendVerificationCode(destination, code);
        } else {
            smsSender.sendVerificationCode(destination, code);
        }
    }

    String hash(String code) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(
                    (properties.effectivePepper() + ":" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    static String mask(String destination) {
        if (destination == null || destination.length() < 4) {
            return "***";
        }
        if (destination.contains("@")) {
            int at = destination.indexOf('@');
            String local = destination.substring(0, at);
            String shown = local.length() <= 2 ? local + "***" : local.substring(0, 2) + "***";
            return shown + destination.substring(at);
        }
        return "***" + destination.substring(destination.length() - 2);
    }

    /** Convenience for post-registration flows that need the user's entity. */
    public static boolean userNeedsVerification(User user) {
        if (user.getPhone() != null && !user.isPhoneVerified()) {
            return true;
        }
        return !user.isEmailVerified();
    }
}
