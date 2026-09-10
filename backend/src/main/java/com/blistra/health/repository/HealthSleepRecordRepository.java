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

    @Query(value = """
            SELECT s.* FROM health_sleep_records s
            WHERE s.user_id = :userId
              AND (CAST(:from AS timestamptz) IS NULL OR s.started_at >= :from)
              AND (CAST(:to AS timestamptz) IS NULL OR s.started_at <= :to)
            ORDER BY s.started_at DESC
            """, nativeQuery = true)
    Page<HealthSleepRecord> search(@Param("userId") UUID userId,
                                   @Param("from") OffsetDateTime from,
                                   @Param("to") OffsetDateTime to,
                                   Pageable pageable);
}