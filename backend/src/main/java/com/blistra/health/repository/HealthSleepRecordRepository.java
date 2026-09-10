package com.blistra.health.repository;

import com.blistra.health.domain.HealthSleepRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HealthSleepRecordRepository extends JpaRepository<HealthSleepRecord, UUID> {

    Optional<HealthSleepRecord> findByIdAndUserId(UUID id, UUID userId);

    @Query("""
            SELECT s FROM HealthSleepRecord s
            WHERE s.user.id = :userId
              AND (:from IS NULL OR s.startedAt >= :from)
              AND (:to IS NULL OR s.startedAt <= :to)
            """)
    Page<HealthSleepRecord> search(@Param("userId") UUID userId,
                                   @Param("from") OffsetDateTime from,
                                   @Param("to") OffsetDateTime to,
                                   Pageable pageable);

    @Query("""
            SELECT s FROM HealthSleepRecord s
            WHERE s.user.id = :userId
              AND LOWER(s.notes) LIKE LOWER(:term)
            """)
    Page<HealthSleepRecord> searchByText(@Param("userId") UUID userId,
                                         @Param("term") String term,
                                         Pageable pageable);
}