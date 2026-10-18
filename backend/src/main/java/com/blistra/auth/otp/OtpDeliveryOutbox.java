package com.blistra.auth.otp;

import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.UUID;

/**
 * Transactional OTP delivery. Claim and acknowledgement use short transactions;
 * provider I/O never holds a database connection. A crash after provider acceptance
 * may resend the SAME code (at-least-once delivery), never create a new one.
 */
@Service
@Slf4j
public class OtpDeliveryOutbox {
    private final JdbcTemplate jdbc;
    private final OtpProperties properties;
    private final EmailSender email;
    private final SmsSender sms;
    private final UserRepository users;
    private final VerificationOtpRepository otps;
    private final TransactionTemplate transaction;
    private final SecureRandom random = new SecureRandom();
    private final io.micrometer.core.instrument.Counter acceptedCount,failedCount,exhaustedCount;

    public OtpDeliveryOutbox(JdbcTemplate jdbc, OtpProperties properties, EmailSender email,
                            SmsSender sms, UserRepository users, VerificationOtpRepository otps,
                            PlatformTransactionManager manager,io.micrometer.core.instrument.MeterRegistry meters) {
        this.jdbc = jdbc;
        this.properties = properties;
        this.email = email;
        this.sms = sms;
        this.users = users;
        this.otps = otps;
        this.transaction = new TransactionTemplate(manager);
        acceptedCount=meters.counter("blistra.otp.delivery.attempts","outcome","provider_accepted");
        failedCount=meters.counter("blistra.otp.delivery.attempts","outcome","failed");
        exhaustedCount=meters.counter("blistra.otp.delivery.exhausted");
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void enqueue(UUID otpId, String code) {
        jdbc.update("INSERT INTO otp_delivery_outbox(otp_id, encrypted_code) VALUES (?, ?)",
                otpId, encrypt(otpId, code));
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void cancel(UUID otpId) {
        jdbc.update("DELETE FROM otp_delivery_outbox WHERE otp_id=?",otpId);
    }
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean contains(UUID otpId) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM otp_delivery_outbox WHERE otp_id=?)",Boolean.class,otpId));
    }

    @Scheduled(fixedDelayString = "${blistra.otp.delivery-delay-ms:5000}",
               initialDelayString = "${blistra.otp.delivery-initial-delay-ms:5000}")
    public void deliverPending() {
        if (!properties.isOutboxEnabled()) return;
        // Bounded batches avoid monopolizing the scheduler during an outage.
        for (int i = 0; i < 10; i++) {
            Claim claim = transaction.execute(status -> claim());
            if (claim == null) return;
            boolean accepted = false;
            try {
                String code = decrypt(claim.id, claim.encrypted);
                if (claim.channel == OtpChannel.EMAIL) email.sendVerificationCode(claim.destination, code);
                else sms.sendVerificationCode(claim.destination, code);
                accepted = true;
                acceptedCount.increment();
            } catch (RuntimeException e) {
                failedCount.increment();
                // Never log exception messages, payloads, addresses or codes.
                log.warn("OTP delivery attempt failed ({})", e.getClass().getSimpleName());
            }
            boolean sent = accepted;
            transaction.executeWithoutResult(status -> acknowledge(claim, sent));
        }
    }

    private record Claim(UUID id, UUID userId, OtpChannel channel, String destination,
                         String encrypted, UUID lease, int attempts) {}

    private Claim claim() {
        jdbc.update("""
                DELETE FROM otp_delivery_outbox q USING verification_otps o
                WHERE q.otp_id=o.id AND (o.consumed OR o.expires_at <= (CURRENT_TIMESTAMP AT TIME ZONE 'UTC'))
                """);
        var rows = jdbc.query("""
                SELECT q.otp_id,o.user_id,o.channel,o.destination,q.encrypted_code,q.attempts
                FROM otp_delivery_outbox q JOIN verification_otps o ON o.id=q.otp_id
                WHERE q.available_at <= CURRENT_TIMESTAMP
                AND (q.lease_until IS NULL OR q.lease_until < CURRENT_TIMESTAMP)
                ORDER BY q.available_at,q.otp_id LIMIT 1 FOR UPDATE OF q SKIP LOCKED
                """, (rs, row) -> new Claim(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
                OtpChannel.valueOf(rs.getString(3)), rs.getString(4), rs.getString(5),
                UUID.randomUUID(), rs.getInt(6) + 1));
        if (rows.isEmpty()) return null;
        Claim result = rows.getFirst();
        // Increment before sending so process crashes also count against the budget.
        if (result.attempts > 5) {
            exhaustedCount.increment();
            jdbc.update("DELETE FROM otp_delivery_outbox WHERE otp_id=?", result.id);
            return null;
        }
        jdbc.update("""
                UPDATE otp_delivery_outbox SET lease_token=?,lease_until=CURRENT_TIMESTAMP + INTERVAL '120 seconds',
                attempts=attempts+1 WHERE otp_id=?
                """, result.lease, result.id);
        return result;
    }

    private void acknowledge(Claim claim, boolean accepted) {
        // Match issuance's lock order: parent user, then queue/OTP rows.
        if (users.lockById(claim.userId).isEmpty()) return;
        var lease = jdbc.queryForList("SELECT lease_token FROM otp_delivery_outbox WHERE otp_id=? FOR UPDATE",
                UUID.class, claim.id);
        if (lease.isEmpty() || !claim.lease.equals(lease.getFirst())) return;
        VerificationOtp otp = otps.findById(claim.id).orElseThrow();
        if (accepted && !otp.isExpired() && !otp.isConsumed()) {
            for (VerificationOtp old : otps.findByUserIdAndPurposeAndConsumedFalseOrderByCreatedAtDesc(
                    otp.getUserId(), otp.getPurpose())) {
                if (!old.getId().equals(otp.getId()) && old.isDelivered()) {
                    old.setConsumed(true);
                    old.setConsumedAt(LocalDateTime.now());
                }
            }
            otp.setDelivered(true);
            jdbc.update("DELETE FROM otp_delivery_outbox WHERE otp_id=?", claim.id);
        } else if (otp.isExpired() || otp.isConsumed() || claim.attempts >= 5) {
            if (!accepted && claim.attempts >= 5) exhaustedCount.increment();
            otp.setConsumed(true);
            otp.setConsumedAt(LocalDateTime.now());
            jdbc.update("DELETE FROM otp_delivery_outbox WHERE otp_id=?", claim.id);
        } else {
            jdbc.update("""
                    UPDATE otp_delivery_outbox SET lease_token=NULL,lease_until=NULL,
                    available_at=CURRENT_TIMESTAMP + (? * INTERVAL '1 second') WHERE otp_id=?
                    """, Math.min(120, 15 * claim.attempts), claim.id);
        }
    }

    private String encrypt(UUID id, String code) {
        try {
            byte[] nonce = new byte[12];
            random.nextBytes(nonce);
            Cipher cipher = cipher(Cipher.ENCRYPT_MODE, id, nonce);
            byte[] encrypted = cipher.doFinal(code.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(ByteBuffer.allocate(nonce.length + encrypted.length)
                    .put(nonce).put(encrypted).array());
        } catch (Exception e) {
            throw new IllegalStateException("Could not encrypt queued OTP");
        }
    }

    private String decrypt(UUID id, String payload) {
        try {
            ByteBuffer buffer = ByteBuffer.wrap(Base64.getDecoder().decode(payload));
            byte[] nonce = new byte[12];
            buffer.get(nonce);
            byte[] encrypted = new byte[buffer.remaining()];
            buffer.get(encrypted);
            return new String(cipher(Cipher.DECRYPT_MODE, id, nonce).doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Could not decrypt queued OTP");
        }
    }

    private Cipher cipher(int mode, UUID id, byte[] nonce) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(mode, new SecretKeySpec(Base64.getDecoder().decode(properties.getDeliveryKey()), "AES"),
                new GCMParameterSpec(128, nonce));
        cipher.updateAAD(id.toString().getBytes(StandardCharsets.UTF_8));
        return cipher;
    }
}
