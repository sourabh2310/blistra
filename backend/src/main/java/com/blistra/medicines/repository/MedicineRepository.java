package com.blistra.medicines.repository;

import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicineStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface MedicineRepository extends JpaRepository<Medicine, UUID> {

    Optional<Medicine> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);

    Page<Medicine> findAllByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Page<Medicine> findAllByUserIdAndStatusOrderByCreatedAtDesc(UUID userId, MedicineStatus status, Pageable pageable);

    @Query("""
            SELECT m FROM Medicine m
            WHERE m.user.id = :userId
              AND (LOWER(m.name) LIKE LOWER(:term)
                   OR LOWER(m.genericName) LIKE LOWER(:term)
                   OR LOWER(m.notes) LIKE LOWER(:term))
            """)
    Page<Medicine> searchByText(@Param("userId") UUID userId,
                                @Param("term") String term,
                                Pageable pageable);

    long countByUserIdAndStatus(UUID userId, MedicineStatus status);
}