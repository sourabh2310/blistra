package com.blistra.diet.repository;

import com.blistra.diet.domain.DietProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DietProfileRepository extends JpaRepository<DietProfile, UUID> {

    Optional<DietProfile> findByUserId(UUID userId);

    @Query("""
            SELECT p FROM DietProfile p
            WHERE p.userId = :userId
              AND (LOWER(p.customPreference) LIKE LOWER(:term)
                   OR LOWER(p.dislikedFoods) LIKE LOWER(:term)
                   OR LOWER(p.notes) LIKE LOWER(:term))
            """)
    List<DietProfile> searchByText(@Param("userId") UUID userId,
                                   @Param("term") String term);
}