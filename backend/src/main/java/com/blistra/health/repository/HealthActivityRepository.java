package com.blistra.health.repository;

import com.blistra.health.domain.HealthActivity;
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
public interface HealthActivityRepository extends JpaRepository<HealthActivity, UUID> {

    Optional<HealthActivity> findByIdAndUserId(UUID id, UUID userId);

    @Query(value = """
            SELECT a.* FROM health_activities a
            WHERE a.user_id = :userId
              AND (CAST(:from AS timestamptz) IS NULL OR a.performed_at >= :from)
              AND (CAST(:to AS timestamptz) IS NULL OR a.performed_at <= :to)
            """, nativeQuery = true)
    Page<HealthActivity> search(@Param("userId") UUID userId,
                                @Param("from") OffsetDateTime from,
                                @Param("to") OffsetDateTime to,
                                Pageable pageable);
}