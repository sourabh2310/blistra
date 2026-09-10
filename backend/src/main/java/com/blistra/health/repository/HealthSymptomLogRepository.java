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

    @Query("""
            SELECT l FROM HealthSymptomLog l
            WHERE l.user.id = :userId
              AND (:from IS NULL OR l.observedAt >= :from)
              AND (:to IS NULL OR l.observedAt <= :to)
            """)
    Page<HealthSymptomLog> search(@Param("userId") UUID userId,
                                  @Param("from") OffsetDateTime from,
                                  @Param("to") OffsetDateTime to,
                                  Pageable pageable);

    @Query("""
            SELECT l FROM HealthSymptomLog l
            WHERE l.user.id = :userId
              AND (LOWER(l.title) LIKE LOWER(:term)
                   OR LOWER(l.description) LIKE LOWER(:term)
                   OR LOWER(l.notes) LIKE LOWER(:term))
            """)
    Page<HealthSymptomLog> searchByText(@Param("userId") UUID userId,
                                        @Param("term") String term,
                                        Pageable pageable);
}