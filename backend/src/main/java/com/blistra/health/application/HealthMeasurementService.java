package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthMeasurement;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.dto.MeasurementRequest;
import com.blistra.health.dto.MeasurementResponse;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.repository.HealthMeasurementRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
@Transactional
public class HealthMeasurementService {

    private final HealthMeasurementRepository measurementRepository;
    private final CurrentUserProvider currentUserProvider;
    private final MeasurementValidator measurementValidator;

    public HealthMeasurementService(HealthMeasurementRepository measurementRepository,
                                    CurrentUserProvider currentUserProvider,
                                    MeasurementValidator measurementValidator) {
        this.measurementRepository = measurementRepository;
        this.currentUserProvider = currentUserProvider;
        this.measurementValidator = measurementValidator;
    }

    @Transactional(readOnly = true)
    public PageResponse<MeasurementResponse> list(MeasurementType type,
                                                  OffsetDateTime from,
                                                  OffsetDateTime to,
                                                  Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<HealthMeasurement> page = measurementRepository.search(user.getId(), type, from, to, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public MeasurementResponse create(MeasurementRequest request) {
        measurementValidator.validate(request);
        User user = currentUserProvider.getCurrentUser();
        HealthMeasurement measurement = new HealthMeasurement();
        measurement.setUser(user);
        measurement.setType(request.getType());
        measurement.setMeasuredAt(request.getMeasuredAt());
        measurement.setValue(request.getValue());
        measurement.setValueDiastolic(request.getValueDiastolic());
        measurement.setUnit(request.getUnit().toUpperCase());
        measurement.setSource(request.getSource());
        measurement.setNotes(request.getNotes());
        return toResponse(measurementRepository.save(measurement));
    }

    @Transactional(readOnly = true)
    public MeasurementResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public MeasurementResponse update(UUID id, MeasurementRequest request) {
        measurementValidator.validate(request);
        User user = currentUserProvider.getCurrentUser();
        HealthMeasurement measurement = getOwned(id, user.getId());
        measurement.setType(request.getType());
        measurement.setMeasuredAt(request.getMeasuredAt());
        measurement.setValue(request.getValue());
        measurement.setValueDiastolic(request.getValueDiastolic());
        measurement.setUnit(request.getUnit().toUpperCase());
        measurement.setSource(request.getSource());
        measurement.setNotes(request.getNotes());
        return toResponse(measurementRepository.save(measurement));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthMeasurement measurement = getOwned(id, user.getId());
        measurementRepository.delete(measurement);
    }

    private HealthMeasurement getOwned(UUID id, UUID userId) {
        return measurementRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Measurement not found"));
    }

    private MeasurementResponse toResponse(HealthMeasurement measurement) {
        return MeasurementResponse.builder()
                .id(measurement.getId())
                .type(measurement.getType())
                .measuredAt(measurement.getMeasuredAt())
                .value(measurement.getValue())
                .valueDiastolic(measurement.getValueDiastolic())
                .unit(measurement.getUnit())
                .source(measurement.getSource())
                .notes(measurement.getNotes())
                .createdAt(measurement.getCreatedAt())
                .updatedAt(measurement.getUpdatedAt())
                .build();
    }
}