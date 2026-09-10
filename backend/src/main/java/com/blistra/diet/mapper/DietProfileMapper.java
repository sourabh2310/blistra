package com.blistra.diet.mapper;

import com.blistra.diet.domain.DietProfile;
import com.blistra.diet.dto.DietProfileRequest;
import com.blistra.diet.dto.DietProfileResponse;

public final class DietProfileMapper {

    private DietProfileMapper() {
    }

    public static DietProfileResponse toResponse(DietProfile profile) {
        return DietProfileResponse.builder()
                .dietaryPreference(profile.getDietaryPreference())
                .customPreference(profile.getCustomPreference())
                .dislikedFoods(profile.getDislikedFoods())
                .notes(profile.getNotes())
                .createdAt(profile.getCreatedAt())
                .updatedAt(profile.getUpdatedAt())
                .build();
    }

    public static void applyRequest(DietProfile profile, DietProfileRequest request) {
        profile.setDietaryPreference(request.getDietaryPreference());
        profile.setCustomPreference(request.getCustomPreference());
        profile.setDislikedFoods(request.getDislikedFoods());
        profile.setNotes(request.getNotes());
    }
}