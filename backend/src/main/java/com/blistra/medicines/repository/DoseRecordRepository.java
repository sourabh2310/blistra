package com.blistra.medicines.repository;

import com.blistra.medicines.domain.DoseRecord;
import com.blistra.medicines.domain.DoseStatus;
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
public interface DoseRecordRepository extends JpaRepository<DoseRecord, UUID> {

    Page<DoseRecord> findAllByMedicineIdAndMedicineUserIdOrderByScheduledAtDesc(
            UUID medicineId, UUID userId, Pageable pageable);

    Optional<DoseRecord> findByIdAndMedicineIdAndMedicineUserId(UUID doseId, UUID medicineId, UUID userId);

    @Query("""
            SELECT d FROM DoseRecord d
            WHERE d.medicine.user.id = :userId
              AND d.scheduledAt >= :from
              AND d.scheduledAt <= :to
            ORDER BY d.scheduledAt ASC
            """)
    List<DoseRecord> findByUserIdAndScheduledAtBetween(
            @Param("userId") UUID userId,
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to);

    @Query("""
            SELECT count(d) FROM DoseRecord d
            WHERE d.medicine.user.id = :userId
              AND d.scheduledAt >= :from
              AND d.scheduledAt <= :to
              AND d.status = :status
            """)
    long countByUserIdAndScheduledAtBetweenAndStatus(
            @Param("userId") UUID userId,
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("status") DoseStatus status);
}