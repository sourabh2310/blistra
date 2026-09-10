package com.blistra.health.repository;

import com.blistra.health.domain.HealthProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface HealthProfileRepository extends JpaRepository<HealthProfile, UUID> {

    Optional<HealthProfile> findByUserId(UUID userId);

    boolean existsByUserId(UUID userId);
}