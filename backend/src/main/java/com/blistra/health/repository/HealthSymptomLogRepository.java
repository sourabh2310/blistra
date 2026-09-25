package com.blistra.health.repository;

import com.blistra.health.domain.HealthSymptomLog;
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
public interface HealthSymptomLogRepository extends JpaRepository<HealthSymptomLog, UUID> {

    Optional<HealthSymptomLog> findByIdAndUserId(UUID id, UUID userId);

    @Query(value = """
            SELECT l.* FROM health_symptom_logs l
            WHERE l.user_id = :userId
              AND (CAST(:from AS timestamptz) IS NULL OR l.observed_at >= :from)
              AND (CAST(:to AS timestamptz) IS NULL OR l.observed_at <= :to)
            """, nativeQuery = true)
    Page<HealthSymptomLog> search(@Param("userId") UUID userId,
                                  @Param("from") OffsetDateTime from,
                                  @Param("to") OffsetDateTime to,
                                  Pageable pageable);
}