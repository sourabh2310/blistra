package com.blistra.medicines.repository;

import com.blistra.medicines.domain.MedicationSchedule;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MedicationScheduleRepository extends JpaRepository<MedicationSchedule, UUID> {

    List<MedicationSchedule> findAllByMedicineIdAndMedicineUserIdOrderByCreatedAtAsc(UUID medicineId, UUID userId);

    Optional<MedicationSchedule> findByIdAndMedicineIdAndMedicineUserId(
            UUID scheduleId, UUID medicineId, UUID userId);

    // The today expansion reads each schedule's medicine; fetch-join it to
    // avoid one lazy query per schedule.
    @EntityGraph(attributePaths = {"medicine"})
    @Query("""
            SELECT s FROM MedicationSchedule s
            WHERE s.medicine.user.id = :userId
              AND s.active = true
            ORDER BY s.createdAt ASC
            """)
    List<MedicationSchedule> findActiveByUserId(@Param("userId") UUID userId);
}