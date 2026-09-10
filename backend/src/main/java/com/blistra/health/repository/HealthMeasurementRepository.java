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

    @Query(value = """
            SELECT m.* FROM health_measurements m
            WHERE m.user_id = :userId
              AND (CAST(:type AS text) IS NULL OR m.type = :type)
              AND (CAST(:from AS timestamptz) IS NULL OR m.measured_at >= :from)
              AND (CAST(:to AS timestamptz) IS NULL OR m.measured_at <= :to)
            ORDER BY m.measured_at DESC
            """, nativeQuery = true)
    Page<HealthMeasurement> search(@Param("userId") UUID userId,
                                   @Param("type") String type,
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
}