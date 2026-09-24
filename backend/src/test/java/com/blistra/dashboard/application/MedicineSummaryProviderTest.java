package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.medicines.application.MedicineTodayService;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.dto.MedicineTodayResponse;
import com.blistra.medicines.dto.TodayDoseResponse;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MedicineSummaryProviderTest {

    @Mock
    private MedicineRepository medicineRepository;

    @Mock
    private MedicineTodayService medicineTodayService;

    @Mock
    private CurrentUserProvider currentUserProvider;

    @Mock
    private User user;

    private MedicineSummaryProvider provider;
    private UUID userId;

    @BeforeEach
    void setUp() {
        provider = new MedicineSummaryProvider(medicineRepository, medicineTodayService, currentUserProvider);
        userId = UUID.randomUUID();
        lenient().when(user.getId()).thenReturn(userId);
        lenient().when(currentUserProvider.getCurrentUser()).thenReturn(user);
    }

    @Test
    void getMedicineSummaryMapsExpectedDosesForRequestedDateAndOffset() {
        LocalDate date = LocalDate.of(2026, 9, 24);
        UUID medicineId = UUID.randomUUID();
        UUID scheduleId = UUID.randomUUID();
        UUID recordId = UUID.randomUUID();
        OffsetDateTime scheduledAt = date.atTime(8, 0).atOffset(java.time.ZoneOffset.ofTotalSeconds(19800));
        OffsetDateTime takenAt = scheduledAt.plusMinutes(5);
        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(3L);
        when(medicineTodayService.getToday(date, 330)).thenReturn(MedicineTodayResponse.builder()
                .date(date)
                .totalDoses(2)
                .takenDoses(1)
                .remainingDoses(1)
                .doses(List.of(
                        TodayDoseResponse.builder()
                                .medicineId(medicineId)
                                .medicineName("Medicine A")
                                .scheduleId(scheduleId)
                                .scheduledAt(scheduledAt)
                                .status("PENDING")
                                .doseAmount("500")
                                .doseUnit("mg")
                                .build(),
                        TodayDoseResponse.builder()
                                .medicineId(medicineId)
                                .medicineName("Medicine A")
                                .scheduleId(scheduleId)
                                .scheduledAt(scheduledAt.plusHours(12))
                                .status("TAKEN")
                                .takenAt(takenAt)
                                .doseRecordId(recordId)
                                .doseAmount("500")
                                .doseUnit("mg")
                                .build()))
                .build());

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(date, 330);

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getActiveMedicineCount()).isEqualTo(3);
        assertThat(section.getDosesToday()).hasSize(2);
        assertThat(section.getDosesToday().get(0).getStatus()).isEqualTo("PENDING");
        assertThat(section.getDosesToday().get(0).getId()).isNull();
        assertThat(section.getDosesToday().get(1).getId()).isEqualTo(recordId.toString());
        assertThat(section.getDosesTakenToday()).isEqualTo(1);
        assertThat(section.getDosesRemainingToday()).isEqualTo(1);
        verify(medicineTodayService).getToday(date, 330);
    }

    @Test
    void getMedicineSummaryHandlesExpectedScheduleFailureGracefully() {
        LocalDate date = LocalDate.of(2026, 9, 24);
        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(1L);
        when(medicineTodayService.getToday(date, 0)).thenThrow(new RuntimeException("DB down"));

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(date, 0);

        assertThat(section.isUnavailable()).isTrue();
        assertThat(section.getError()).isEqualTo("Medicine summary unavailable");
        assertThat(section.getDosesToday()).isNull();
    }

    @Test
    void getMedicineSummaryReturnsEmptyExpectedSchedule() {
        LocalDate date = LocalDate.of(2026, 9, 24);
        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(0L);
        when(medicineTodayService.getToday(date, 0)).thenReturn(MedicineTodayResponse.builder()
                .date(date)
                .doses(List.of())
                .build());

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(date, 0);

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getDosesToday()).isEmpty();
        assertThat(section.getDosesTakenToday()).isZero();
        assertThat(section.getDosesRemainingToday()).isZero();
    }
}
