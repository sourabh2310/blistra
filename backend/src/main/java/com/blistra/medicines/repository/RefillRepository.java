package com.blistra.medicines.repository;

import com.blistra.medicines.domain.Refill;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefillRepository extends JpaRepository<Refill, UUID> {

    Page<Refill> findAllByMedicineIdAndMedicineUserIdOrderByRefillDateDesc(
            UUID medicineId, UUID userId, Pageable pageable);

    Optional<Refill> findByIdAndMedicineIdAndMedicineUserId(UUID refillId, UUID medicineId, UUID userId);
}