package com.blistra.health.repository;

import com.blistra.health.domain.HealthEvent;
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
public interface HealthEventRepository extends JpaRepository<HealthEvent, UUID> {

    Optional<HealthEvent> findByIdAndUserId(UUID id, UUID userId);

    @Query(value = """
            SELECT e.* FROM health_events e
            WHERE e.user_id = :userId
              AND (CAST(:from AS timestamptz) IS NULL OR e.occurred_at >= :from)
              AND (CAST(:to AS timestamptz) IS NULL OR e.occurred_at <= :to)
            ORDER BY e.occurred_at DESC
            """, nativeQuery = true)
    Page<HealthEvent> search(@Param("userId") UUID userId,
                             @Param("from") OffsetDateTime from,
                             @Param("to") OffsetDateTime to,
                             Pageable pageable);
}