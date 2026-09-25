package com.blistra.auth.otp;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VerificationOtpRepository extends JpaRepository<VerificationOtp, UUID> {

    List<VerificationOtp> findByUserIdAndPurposeAndConsumedFalseOrderByCreatedAtDesc(
            UUID userId, OtpPurpose purpose);

    default Optional<VerificationOtp> findLatestActive(UUID userId, OtpPurpose purpose) {
        return findByUserIdAndPurposeAndConsumedFalseOrderByCreatedAtDesc(userId, purpose)
                .stream()
                .findFirst();
    }

    long countByUserIdAndPurposeAndCreatedAtAfter(
            UUID userId, OtpPurpose purpose, LocalDateTime since);
}
