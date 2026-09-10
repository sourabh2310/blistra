package com.blistra.diet.mapper;

import com.blistra.diet.domain.WaterIntake;
import com.blistra.diet.dto.WaterRequest;
import com.blistra.diet.dto.WaterResponse;

public final class WaterMapper {

    private WaterMapper() {
    }

    public static WaterResponse toResponse(WaterIntake water) {
        return WaterResponse.builder()
                .id(water.getId())
                .amount(water.getAmount())
                .unit(water.getUnit())
                .consumedAt(water.getConsumedAt())
                .createdAt(water.getCreatedAt())
                .updatedAt(water.getUpdatedAt())
                .build();
    }

    public static void applyRequest(WaterIntake water, WaterRequest request) {
        water.setAmount(request.getAmount());
        water.setUnit(request.getUnit());
        water.setConsumedAt(request.getConsumedAt());
    }
}