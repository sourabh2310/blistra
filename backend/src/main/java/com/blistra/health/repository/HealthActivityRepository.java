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

    @Query("""
            SELECT a FROM HealthActivity a
            WHERE a.user.id = :userId
              AND (:from IS NULL OR a.performedAt >= :from)
              AND (:to IS NULL OR a.performedAt <= :to)
            """)
    Page<HealthActivity> search(@Param("userId") UUID userId,
                                @Param("from") OffsetDateTime from,
                                @Param("to") OffsetDateTime to,
                                Pageable pageable);

    @Query("""
            SELECT a FROM HealthActivity a
            WHERE a.user.id = :userId
              AND LOWER(a.notes) LIKE LOWER(:term)
            """)
    Page<HealthActivity> searchByText(@Param("userId") UUID userId,
                                      @Param("term") String term,
                                      Pageable pageable);
}