package com.blistra.health.repository;

import com.blistra.health.domain.HealthAppointment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HealthAppointmentRepository extends JpaRepository<HealthAppointment, UUID> {

    Optional<HealthAppointment> findByIdAndUserId(UUID id, UUID userId);

    @Query("""
            SELECT a FROM HealthAppointment a
            WHERE a.user.id = :userId
              AND (:from IS NULL OR a.scheduledAt >= :from)
              AND (:to IS NULL OR a.scheduledAt <= :to)
            """)
    Page<HealthAppointment> search(@Param("userId") UUID userId,
                                   @Param("from") OffsetDateTime from,
                                   @Param("to") OffsetDateTime to,
                                   Pageable pageable);

    @Query("""
            SELECT a FROM HealthAppointment a
            WHERE a.user.id = :userId
              AND a.scheduledAt >= :from
              AND a.scheduledAt <= :to
            ORDER BY a.scheduledAt ASC
            """)
    List<HealthAppointment> findUpcomingByUserIdOrderByScheduledAtAsc(
            @Param("userId") UUID userId,
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to);

    @Query("""
            SELECT a FROM HealthAppointment a
            WHERE a.user.id = :userId
              AND (LOWER(a.title) LIKE LOWER(:term)
                   OR LOWER(a.location) LIKE LOWER(:term)
                   OR LOWER(a.notes) LIKE LOWER(:term))
            """)
    Page<HealthAppointment> searchByText(@Param("userId") UUID userId,
                                         @Param("term") String term,
                                         Pageable pageable);
}