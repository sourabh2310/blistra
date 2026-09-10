package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.domain.HealthMeasurement;
import com.blistra.health.domain.HealthAppointment;
import com.blistra.health.repository.HealthMeasurementRepository;
import com.blistra.health.repository.HealthAppointmentRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Dashboard-internal adapter that reads Health data for aggregation.
 *
 * <p>This is part of the Dashboard module, not the Health module. It uses
 * Health's repositories directly for read-only summary queries, avoiding
 * duplicate business logic while keeping the Dashboard as a pure aggregation layer.</p>
 */
@Component
public class HealthSummaryProvider {

    private final HealthMeasurementRepository measurementRepository;
    private final HealthAppointmentRepository appointmentRepository;
    private final CurrentUserProvider currentUserProvider;

    public HealthSummaryProvider(HealthMeasurementRepository measurementRepository,
                                  HealthAppointmentRepository appointmentRepository,
                                  CurrentUserProvider currentUserProvider) {
        this.measurementRepository = measurementRepository;
        this.appointmentRepository = appointmentRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public DashboardResponse.HealthSection getHealthSummary() {
        try {
            var user = currentUserProvider.getCurrentUser();
            UUID userId = user.getId();

            List<DashboardResponse.MeasurementSummary> measurements = getLatestMeasurements(userId);
            List<DashboardResponse.AppointmentSummary> appointments = getUpcomingAppointments(userId);

            return DashboardResponse.HealthSection.builder()
                    .latestMeasurements(measurements)
                    .upcomingAppointments(appointments)
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.HealthSection.builder()
                    .unavailable(true)
                    .error("Health summary unavailable")
                    .build();
        }
    }

    private List<DashboardResponse.MeasurementSummary> getLatestMeasurements(UUID userId) {
        List<DashboardResponse.MeasurementSummary> result = new ArrayList<>();

        for (MeasurementType type : MeasurementType.values()) {
            Optional<HealthMeasurement> latest = measurementRepository
                    .findLatestByUserIdAndTypeOrderByMeasuredAtDesc(userId, type);

            latest.ifPresent(m -> result.add(DashboardResponse.MeasurementSummary.builder()
                    .type(m.getType().name())
                    .value(m.getValue() != null ? m.getValue().toString() : null)
                    .valueDiastolic(m.getValueDiastolic() != null ? m.getValueDiastolic().toString() : null)
                    .unit(m.getUnit())
                    .measuredAt(m.getMeasuredAt().toString())
                    .build()));
        }

        return result;
    }

    private List<DashboardResponse.AppointmentSummary> getUpcomingAppointments(UUID userId) {
        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime future = now.plusDays(30);

        List<HealthAppointment> appointments = appointmentRepository
                .findUpcomingByUserIdOrderByScheduledAtAsc(userId, now, future);

        return appointments.stream()
                .map(a -> DashboardResponse.AppointmentSummary.builder()
                        .id(a.getId().toString())
                        .title(a.getTitle())
                        .scheduledAt(a.getScheduledAt().toString())
                        .location(a.getLocation())
                        .status(a.getStatus().name())
                        .build())
                .toList();
    }
}