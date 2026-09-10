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

    @Query("""
            SELECT e FROM HealthEvent e
            WHERE e.user.id = :userId
              AND (:from IS NULL OR e.occurredAt >= :from)
              AND (:to IS NULL OR e.occurredAt <= :to)
            """)
    Page<HealthEvent> search(@Param("userId") UUID userId,
                             @Param("from") OffsetDateTime from,
                             @Param("to") OffsetDateTime to,
                             Pageable pageable);

    @Query("""
            SELECT e FROM HealthEvent e
            WHERE e.user.id = :userId
              AND (LOWER(e.title) LIKE LOWER(:term) OR LOWER(e.notes) LIKE LOWER(:term))
            """)
    Page<HealthEvent> searchByText(@Param("userId") UUID userId,
                                   @Param("term") String term,
                                   Pageable pageable);
}