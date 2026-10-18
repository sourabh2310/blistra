package com.blistra.auth;

import com.blistra.auth.otp.*;
import com.blistra.common.exception.OtpVerificationException;
import com.blistra.common.exception.VerificationUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.UUID;
import java.util.concurrent.*;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@TestPropertySource(properties = {"blistra.otp.outbox-enabled=true",
        "blistra.otp.delivery-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "spring.datasource.hikari.maximum-pool-size=2"})
class OtpOutboxIntegrationTest extends AuthFlowTest {
    @Autowired VerificationService verification;
    @Autowired OtpDeliveryOutbox worker;
    @Autowired PlatformTransactionManager manager;
    @Autowired com.blistra.users.repository.UserRepository users;
    @MockitoBean EmailSender email;

    @BeforeEach void clean() { deleteAllUsers(); }

    private UUID register(String name) throws Exception {
        return UUID.fromString(userIdOf(registerFull(name, name + "@example.com", null, "password1")));
    }
    private String code(UUID user) {
        return jdbcTemplate.queryForObject("SELECT dev_code FROM verification_otps WHERE user_id=? ORDER BY created_at DESC LIMIT 1",
                String.class, user);
    }
    private int queued() {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM otp_delivery_outbox", Integer.class);
    }
    private void due() {
        jdbcTemplate.update("UPDATE otp_delivery_outbox SET available_at=CURRENT_TIMESTAMP - INTERVAL '1 minute', lease_until=NULL");
    }

    @Test void sendsOnlyAfterCommitAndNeverPersistsPlaintextInTheQueue() throws Exception {
        UUID user = register("queued");
        String code = code(user);
        verifyNoInteractions(email);
        assertThat(queued()).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject("SELECT encrypted_code FROM otp_delivery_outbox", String.class))
                .doesNotContain(code);
        assertThatThrownBy(() -> verification.verify(user, OtpPurpose.EMAIL_VERIFY, code))
                .isInstanceOf(OtpVerificationException.class);
        worker.deliverPending();
        org.mockito.Mockito.verify(email).sendVerificationCode("queued@example.com", code);
        assertThat(queued()).isZero();
        assertThat(verification.verify(user, OtpPurpose.EMAIL_VERIFY, code).getUserId()).isEqualTo(user);
        clearCooldowns(user.toString());
        new TransactionTemplate(manager).executeWithoutResult(status -> {
            verification.issue(user, OtpPurpose.EMAIL_VERIFY, OtpChannel.EMAIL, "queued@example.com");
            status.setRollbackOnly();
        });
        assertThat(queued()).isZero();
        assertThat(jdbcTemplate.queryForObject("SELECT count(*) FROM verification_otps WHERE user_id=?", Integer.class, user))
                .isEqualTo(1);
        worker.deliverPending();
        verifyNoMoreInteractions(email);
    }

    @Test void retriesSameCodeAndPreservesLastDeliveredCodeDuringAnOutage() throws Exception {
        UUID user = register("retryqueue");
        String old = code(user);
        worker.deliverPending();
        clearCooldowns(user.toString());
        verification.issue(user, OtpPurpose.EMAIL_VERIFY, OtpChannel.EMAIL, "retryqueue@example.com");
        String replacement = code(user);
        doThrow(new VerificationUnavailableException("provider unavailable")).when(email)
                .sendVerificationCode(anyString(), anyString());
        worker.deliverPending();
        assertThat(queued()).isEqualTo(1);
        assertThat(verification.latestActive(user, OtpPurpose.EMAIL_VERIFY).orElseThrow().getDevCode()).isEqualTo(old);
        doNothing().when(email).sendVerificationCode(anyString(), anyString());
        due(); worker.deliverPending();
        org.mockito.Mockito.verify(email, times(2)).sendVerificationCode("retryqueue@example.com", replacement);
        assertThat(queued()).isZero();
        assertThatThrownBy(() -> verification.verify(user, OtpPurpose.EMAIL_VERIFY, old))
                .isInstanceOf(OtpVerificationException.class);
        verification.verify(user, OtpPurpose.EMAIL_VERIFY, replacement);
    }

    @Test void abandonedLeasesRecoverAndExpiredOrExhaustedPayloadsArePurged() throws Exception {
        UUID user = register("leasequeue");
        jdbcTemplate.update("UPDATE otp_delivery_outbox SET lease_token=?,lease_until=CURRENT_TIMESTAMP + INTERVAL '2 minutes'", UUID.randomUUID());
        worker.deliverPending(); verifyNoInteractions(email);
        due(); worker.deliverPending();
        org.mockito.Mockito.verify(email).sendVerificationCode("leasequeue@example.com", code(user));
        clearCooldowns(user.toString());
        verification.issue(user, OtpPurpose.EMAIL_VERIFY, OtpChannel.EMAIL, "leasequeue@example.com");
        jdbcTemplate.update("UPDATE verification_otps SET expires_at='2000-01-01' WHERE delivered=false");
        worker.deliverPending(); assertThat(queued()).isZero();
        clearCooldowns(user.toString());
        verification.issue(user, OtpPurpose.EMAIL_VERIFY, OtpChannel.EMAIL, "leasequeue@example.com");
        doThrow(new VerificationUnavailableException("down")).when(email).sendVerificationCode(anyString(), anyString());
        for (int i=0; i<5; i++) { due(); worker.deliverPending(); }
        assertThat(queued()).isZero();
        assertThat(verification.latestActive(user, OtpPurpose.EMAIL_VERIFY)).isPresent();
    }

    @Test void concurrentWorkersDoNotClaimAnActiveLeaseTwice() throws Exception {
        register("workers");
        var sending = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        doAnswer(invocation -> { sending.countDown(); assertThat(release.await(10, TimeUnit.SECONDS)).isTrue(); return null; })
                .when(email).sendVerificationCode(anyString(), anyString());
        try (var pool = Executors.newFixedThreadPool(2)) {
            var first = pool.submit(worker::deliverPending);
            assertThat(sending.await(10, TimeUnit.SECONDS)).isTrue();
            try { pool.submit(worker::deliverPending).get(5, TimeUnit.SECONDS); }
            finally { release.countDown(); }
            first.get(5, TimeUnit.SECONDS);
        }
        org.mockito.Mockito.verify(email, times(1)).sendVerificationCode(anyString(), anyString());
        assertThat(queued()).isZero();
    }

    @Test void usingPriorCodeCancelsItsQueuedReplacement() throws Exception {
        UUID user=register("cancelpending"); String prior=code(user);
        worker.deliverPending();clearCooldowns(user.toString());
        verification.issue(user,OtpPurpose.EMAIL_VERIFY,OtpChannel.EMAIL,"cancelpending@example.com");
        assertThat(queued()).isEqualTo(1);
        verification.verify(user,OtpPurpose.EMAIL_VERIFY,prior);
        assertThat(queued()).isZero();
        worker.deliverPending();
        org.mockito.Mockito.verify(email,times(1)).sendVerificationCode(anyString(),anyString());
    }

    @Test void verificationRefreshesAnEarlierReadBeforeUpdatingTheAccount() throws Exception {
        UUID id=register("versionrace");String code=code(id);worker.deliverPending();
        try (var pool=Executors.newSingleThreadExecutor()) {
            new TransactionTemplate(manager).executeWithoutResult(status -> {
                var user=users.findById(id).orElseThrow();
                try {
                    pool.submit(() -> jdbcTemplate.update("UPDATE users SET session_version=session_version+1 WHERE id=?",id))
                        .get(5,TimeUnit.SECONDS);
                } catch (Exception e) { throw new IllegalStateException(e); }
                verification.verify(id,OtpPurpose.EMAIL_VERIFY,code);
                user.setEmailVerified(true);users.save(user);
            });
        }
        assertThat(jdbcTemplate.queryForObject("SELECT session_version FROM users WHERE id=?",Integer.class,id)).isEqualTo(1);
    }

    @Test void verificationUsesOnlyTheCallersConnectionAndRollsBackWithTheAccountChange() throws Exception {
        UUID a = register("poolone"), b = register("pooltwo");
        worker.deliverPending();
        String ca = code(a), cb = code(b);
        var barrier = new CyclicBarrier(2);
        try (var pool = Executors.newFixedThreadPool(2)) {
            var tasks = java.util.List.of(pool.submit(() -> checkInTransaction(a, ca, barrier)),
                    pool.submit(() -> checkInTransaction(b, cb, barrier)));
            for (var task : tasks) task.get(10, TimeUnit.SECONDS);
        }
        assertThat(verification.verify(a, OtpPurpose.EMAIL_VERIFY, ca)).isNotNull();
        assertThat(verification.verify(b, OtpPurpose.EMAIL_VERIFY, cb)).isNotNull();
    }
    private void checkInTransaction(UUID user, String code, CyclicBarrier barrier) {
        new TransactionTemplate(manager).executeWithoutResult(status -> {
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            try { barrier.await(5, TimeUnit.SECONDS); }
            catch (Exception e) { throw new IllegalStateException(e); }
            verification.verify(user, OtpPurpose.EMAIL_VERIFY, code);
            status.setRollbackOnly();
        });
    }
}
