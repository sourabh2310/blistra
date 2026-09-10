package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthProfile;
import com.blistra.health.dto.HealthProfileRequest;
import com.blistra.health.dto.HealthProfileResponse;
import com.blistra.health.repository.HealthProfileRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
@Transactional
public class HealthProfileService {

    private final HealthProfileRepository healthProfileRepository;
    private final CurrentUserProvider currentUserProvider;

    public HealthProfileService(HealthProfileRepository healthProfileRepository,
                                CurrentUserProvider currentUserProvider) {
        this.healthProfileRepository = healthProfileRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public HealthProfileResponse get() {
        User user = currentUserProvider.getCurrentUser();
        return healthProfileRepository.findByUserId(user.getId())
                .map(this::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Health profile not found"));
    }

    public HealthProfileResponse saveOrUpdate(HealthProfileRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Optional<HealthProfile> existing = healthProfileRepository.findByUserId(user.getId());
        HealthProfile profile = existing.orElseGet(HealthProfile::new);
        if (!existing.isPresent()) {
            profile.setUser(user);
        }
        profile.setHeightCm(request.getHeightCm());
        profile.setBloodType(request.getBloodType());
        profile.setDateOfBirth(request.getDateOfBirth());
        return toResponse(healthProfileRepository.save(profile));
    }

    private HealthProfileResponse toResponse(HealthProfile profile) {
        return HealthProfileResponse.builder()
                .id(profile.getId())
                .heightCm(profile.getHeightCm())
                .bloodType(profile.getBloodType())
                .dateOfBirth(profile.getDateOfBirth())
                .createdAt(profile.getCreatedAt())
                .updatedAt(profile.getUpdatedAt())
                .build();
    }
}