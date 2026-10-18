package com.blistra.auth.security;

import com.blistra.auth.otp.OtpProperties;
import com.blistra.common.exception.TooManyRequestsException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Locale;

/** Database budgets survive API restarts and apply across instances. */
@Service
public class AuthRateLimiter {
    private final JdbcTemplate jdbc;
    private final OtpProperties otp;
    @Value("${blistra.security.rate-limit.enabled:true}") private boolean enabled;
    public AuthRateLimiter(JdbcTemplate jdbc, OtpProperties otp) { this.jdbc = jdbc; this.otp = otp; }

    @Transactional(propagation = Propagation.REQUIRES_NEW, noRollbackFor = TooManyRequestsException.class)
    public void attempt(String scope, String identifier, int maximum) {
        if (!enabled) return;
        long window = Instant.now().getEpochSecond() / 900;
        String key;
        try {
            key = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(
                    (otp.effectivePepper() + ":" + scope + ":" + identifier.trim().toLowerCase(Locale.ROOT))
                            .getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
        Integer hits = jdbc.queryForObject("""
                INSERT INTO authentication_rate_limits(bucket_key, window_start, hits, expires_at)
                VALUES (?, ?, 1, CURRENT_TIMESTAMP + INTERVAL '30 minutes')
                ON CONFLICT (bucket_key, window_start) DO UPDATE
                SET hits = LEAST(authentication_rate_limits.hits, ?) + 1 RETURNING hits
                """, Integer.class, key, window,maximum);
        if (hits != null && hits > maximum) throw new TooManyRequestsException("Too many attempts. Please try again later.");
    }

    @org.springframework.scheduling.annotation.Scheduled(fixedDelay = 900000, initialDelay = 900000)
    public void expire() {
        if (enabled) jdbc.update("DELETE FROM authentication_rate_limits WHERE expires_at < CURRENT_TIMESTAMP");
    }
}
