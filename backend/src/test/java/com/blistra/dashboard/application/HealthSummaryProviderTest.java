package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.health.domain.HealthAppointment;
import com.blistra.health.domain.HealthMeasurement;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.repository.HealthAppointmentRepository;
import com.blistra.health.repository.HealthMeasurementRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HealthSummaryProviderTest {

    @Mock
    private HealthMeasurementRepository measurementRepository;

    @Mock
    private HealthAppointmentRepository appointmentRepository;

    @Mock
    private CurrentUserProvider currentUserProvider;

    @Mock
    private User testUser;

    private HealthSummaryProvider provider;

    @BeforeEach
    void setUp() {
        provider = new HealthSummaryProvider(measurementRepository, appointmentRepository, currentUserProvider);

        lenient().when(testUser.getId()).thenReturn(UUID.randomUUID());
        lenient().when(currentUserProvider.getCurrentUser()).thenReturn(testUser);
    }

    @Test
    void getHealthSummaryReturnsLatestMeasurementsAndAppointments() {
        UUID userId = testUser.getId();

        // Setup latest measurements
        HealthMeasurement weight = new HealthMeasurement();
        weight.setType(MeasurementType.WEIGHT);
        weight.setValue(java.math.BigDecimal.valueOf(70.5));
        weight.setUnit("kg");
        weight.setMeasuredAt(OffsetDateTime.now().minusDays(1));

        HealthMeasurement bp = new HealthMeasurement();
        bp.setType(MeasurementType.BLOOD_PRESSURE);
        bp.setValue(java.math.BigDecimal.valueOf(120));
        bp.setValueDiastolic(java.math.BigDecimal.valueOf(80));
        bp.setUnit("mmHg");
        bp.setMeasuredAt(OffsetDateTime.now().minusHours(2));

        when(measurementRepository.findLatestByUserIdAndTypeOrderByMeasuredAtDesc(userId, MeasurementType.WEIGHT))
                .thenReturn(Optional.of(weight));
        when(measurementRepository.findLatestByUserIdAndTypeOrderByMeasuredAtDesc(userId, MeasurementType.BLOOD_PRESSURE))
                .thenReturn(Optional.of(bp));
        // Other types return empty
        for (MeasurementType type : MeasurementType.values()) {
            if (type != MeasurementType.WEIGHT && type != MeasurementType.BLOOD_PRESSURE) {
                when(measurementRepository.findLatestByUserIdAndTypeOrderByMeasuredAtDesc(userId, type))
                        .thenReturn(Optional.empty());
            }
        }

        // Setup upcoming appointments
        HealthAppointment appt = new HealthAppointment();
        appt.setId(UUID.randomUUID());
        appt.setTitle("Dentist");
        appt.setScheduledAt(OffsetDateTime.now().plusDays(2));
        appt.setLocation("Clinic A");
        appt.setStatus(com.blistra.health.domain.AppointmentStatus.SCHEDULED);

        when(appointmentRepository.findUpcomingByUserIdOrderByScheduledAtAsc(any(), any(), any()))
                .thenReturn(List.of(appt));

        DashboardResponse.HealthSection section = provider.getHealthSummary();

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getLatestMeasurements()).hasSize(2);
        assertThat(section.getLatestMeasurements().stream()
                .map(DashboardResponse.MeasurementSummary::getType)
                .toList()).containsExactlyInAnyOrder("WEIGHT", "BLOOD_PRESSURE");
        assertThat(section.getUpcomingAppointments()).hasSize(1);
        assertThat(section.getUpcomingAppointments().get(0).getTitle()).isEqualTo("Dentist");
    }

    @Test
    void getHealthSummaryHandlesRepositoryExceptionGracefully() {
        when(currentUserProvider.getCurrentUser()).thenThrow(new RuntimeException("DB connection failed"));

        DashboardResponse.HealthSection section = provider.getHealthSummary();

        assertThat(section.isUnavailable()).isTrue();
        assertThat(section.getError()).isEqualTo("Health summary unavailable");
        assertThat(section.getLatestMeasurements()).isNull();
        assertThat(section.getUpcomingAppointments()).isNull();
    }

    @Test
    void getHealthSummaryReturnsEmptyWhenNoData() {
        UUID userId = testUser.getId();

        for (MeasurementType type : MeasurementType.values()) {
            when(measurementRepository.findLatestByUserIdAndTypeOrderByMeasuredAtDesc(userId, type))
                    .thenReturn(Optional.empty());
        }
        when(appointmentRepository.findUpcomingByUserIdOrderByScheduledAtAsc(any(), any(), any()))
                .thenReturn(List.of());

        DashboardResponse.HealthSection section = provider.getHealthSummary();

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getLatestMeasurements()).isEmpty();
        assertThat(section.getUpcomingAppointments()).isEmpty();
    }
}