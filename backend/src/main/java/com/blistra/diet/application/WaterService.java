package com.blistra.diet.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.diet.domain.WaterIntake;
import com.blistra.diet.dto.PageResponse;
import com.blistra.diet.dto.WaterRequest;
import com.blistra.diet.dto.WaterResponse;
import com.blistra.diet.mapper.WaterMapper;
import com.blistra.diet.repository.WaterIntakeRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

@Service
public class WaterService {

    private static final Sort CONSUMED_AT_DESC = Sort.by(Sort.Direction.DESC, "consumedAt");

    private final WaterIntakeRepository waterIntakeRepository;

    public WaterService(WaterIntakeRepository waterIntakeRepository) {
        this.waterIntakeRepository = waterIntakeRepository;
    }

    @Transactional
    public WaterResponse create(UUID userId, WaterRequest request) {
        WaterIntake water = new WaterIntake(userId, request.getAmount(), request.getUnit(),
                request.getConsumedAt());
        return WaterMapper.toResponse(waterIntakeRepository.save(water));
    }

    @Transactional(readOnly = true)
    public WaterResponse get(UUID userId, UUID waterId) {
        return WaterMapper.toResponse(ownedWater(userId, waterId));
    }

    @Transactional
    public WaterResponse update(UUID userId, UUID waterId, WaterRequest request) {
        WaterIntake water = ownedWater(userId, waterId);
        WaterMapper.applyRequest(water, request);
        return WaterMapper.toResponse(waterIntakeRepository.save(water));
    }

    @Transactional
    public void delete(UUID userId, UUID waterId) {
        WaterIntake water = ownedWater(userId, waterId);
        waterIntakeRepository.delete(water);
    }

    @Transactional(readOnly = true)
    public PageResponse<WaterResponse> list(UUID userId, LocalDate date, int offsetMinutes,
                                            int page, int size) {
        PageRequest pageable = PageRequest.of(page, size, CONSUMED_AT_DESC);
        Page<WaterIntake> result;
        if (date != null) {
            DayRange range = DayRange.of(date, offsetMinutes);
            result = waterIntakeRepository
                    .findAllByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThanOrderByConsumedAtDesc(
                            userId, range.start(), range.end(), pageable);
        } else {
            result = waterIntakeRepository.findAllByUserIdOrderByConsumedAtDesc(userId, pageable);
        }

        return PageResponse.<WaterResponse>builder()
                .content(result.getContent().stream().map(WaterMapper::toResponse).toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .build();
    }

    private WaterIntake ownedWater(UUID userId, UUID waterId) {
        return waterIntakeRepository.findByIdAndUserId(waterId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Water record not found"));
    }
}