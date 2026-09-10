package com.blistra.diet.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.diet.domain.DietProfile;
import com.blistra.diet.domain.DietaryPreference;
import com.blistra.diet.dto.DietProfileRequest;
import com.blistra.diet.dto.DietProfileResponse;
import com.blistra.diet.mapper.DietProfileMapper;
import com.blistra.diet.repository.DietProfileRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class DietProfileService {

    private final DietProfileRepository dietProfileRepository;

    public DietProfileService(DietProfileRepository dietProfileRepository) {
        this.dietProfileRepository = dietProfileRepository;
    }

    @Transactional(readOnly = true)
    public DietProfileResponse getProfile(UUID userId) {
        return dietProfileRepository.findByUserId(userId)
                .map(DietProfileMapper::toResponse)
                .orElseGet(DietProfileResponse::new);
    }

    @Transactional
    public DietProfileResponse upsertProfile(UUID userId, DietProfileRequest request) {
        DietaryPreference preference = request.getDietaryPreference();

        if (preference == DietaryPreference.OTHER && (request.getCustomPreference() == null
                || request.getCustomPreference().isBlank())) {
            throw new BadRequestException(
                    "customPreference is required when dietaryPreference is OTHER");
        }

        DietProfile profile = dietProfileRepository.findByUserId(userId)
                .orElseGet(() -> new DietProfile(userId));

        DietProfileMapper.applyRequest(profile, request);
        if (preference != DietaryPreference.OTHER) {
            profile.setCustomPreference(null);
        }

        return DietProfileMapper.toResponse(dietProfileRepository.save(profile));
    }
}