package com.blistra.health.repository;

import com.blistra.health.domain.HealthMeasurement;
import com.blistra.health.domain.MeasurementType;
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
public interface HealthMeasurementRepository extends JpaRepository<HealthMeasurement, UUID> {

    Optional<HealthMeasurement> findByIdAndUserId(UUID id, UUID userId);

    @Query("""
            SELECT m FROM HealthMeasurement m
            WHERE m.user.id = :userId
              AND (:type IS NULL OR m.type = :type)
              AND (:from IS NULL OR m.measuredAt >= :from)
              AND (:to IS NULL OR m.measuredAt <= :to)
            """)
    Page<HealthMeasurement> search(@Param("userId") UUID userId,
                                   @Param("type") MeasurementType type,
                                   @Param("from") OffsetDateTime from,
                                   @Param("to") OffsetDateTime to,
                                   Pageable pageable);

    @Query("""
            SELECT m FROM HealthMeasurement m
            WHERE m.user.id = :userId
              AND m.type = :type
            ORDER BY m.measuredAt DESC
            """)
    Optional<HealthMeasurement> findLatestByUserIdAndTypeOrderByMeasuredAtDesc(
            @Param("userId") UUID userId,
            @Param("type") MeasurementType type);

    @Query("""
            SELECT m FROM HealthMeasurement m
            WHERE m.user.id = :userId
              AND (LOWER(m.notes) LIKE LOWER(:term) OR LOWER(m.source) LIKE LOWER(:term))
            """)
    Page<HealthMeasurement> searchByText(@Param("userId") UUID userId,
                                         @Param("term") String term,
                                         Pageable pageable);
}