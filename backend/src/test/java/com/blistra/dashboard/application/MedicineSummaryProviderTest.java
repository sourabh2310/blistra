package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.medicines.domain.DoseRecord;
import com.blistra.medicines.domain.DoseStatus;
import com.blistra.medicines.domain.MedicationSchedule;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.domain.ScheduleType;
import com.blistra.medicines.repository.DoseRecordRepository;
import com.blistra.medicines.repository.MedicationScheduleRepository;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MedicineSummaryProviderTest {

    @Mock
    private MedicineRepository medicineRepository;

    @Mock
    private MedicationScheduleRepository scheduleRepository;

    @Mock
    private DoseRecordRepository doseRepository;

    @Mock
    private CurrentUserProvider currentUserProvider;

    @Mock
    private User testUser;

    private MedicineSummaryProvider provider;

    @BeforeEach
    void setUp() {
        provider = new MedicineSummaryProvider(medicineRepository, scheduleRepository, doseRepository, currentUserProvider);

        when(testUser.getId()).thenReturn(UUID.randomUUID());
        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);
    }

    @Test
    void getMedicineSummaryReturnsActiveCountAndTodaysDoses() {
        UUID userId = testUser.getId();
        int offsetMinutes = 330;

        ZoneOffset offset = ZoneOffset.ofTotalSeconds(offsetMinutes * 60L);
        OffsetDateTime todayStart = OffsetDateTime.now(offset).withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime todayEnd = todayStart.plusDays(1);

        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(3L);

        // Create today's doses
        Medicine med1 = new Medicine();
        med1.setId(UUID.randomUUID());
        med1.setName("Medicine A");

        MedicationSchedule sched1 = new MedicationSchedule();
        sched1.setId(UUID.randomUUID());
        sched1.setDoseAmount(BigDecimal.valueOf(500));
        sched1.setDoseUnit("mg");

        DoseRecord dose1 = new DoseRecord();
        dose1.setId(UUID.randomUUID());
        dose1.setMedicine(med1);
        dose1.setSchedule(sched1);
        dose1.setStatus(DoseStatus.TAKEN);
        dose1.setScheduledAt(todayStart.plusHours(8));
        dose1.setTakenAt(todayStart.plusHours(8).plusMinutes(5));

        DoseRecord dose2 = new DoseRecord();
        dose2.setId(UUID.randomUUID());
        dose2.setMedicine(med1);
        dose2.setSchedule(sched1);
        dose2.setStatus(DoseStatus.MISSED);
        dose2.setScheduledAt(todayStart.plusHours(20));

        when(doseRepository.findByUserIdAndScheduledAtBetween(userId, todayStart, todayEnd))
                .thenReturn(List.of(dose1, dose2));
        when(doseRepository.countByUserIdAndScheduledAtBetweenAndStatus(userId, todayStart, todayEnd, DoseStatus.TAKEN))
                .thenReturn(1L);

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(offsetMinutes);

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getActiveMedicineCount()).isEqualTo(3);
        assertThat(section.getDosesToday()).hasSize(2);
        assertThat(section.getDosesTakenToday()).isEqualTo(1);
        assertThat(section.getDosesRemainingToday()).isEqualTo(1);

        DashboardResponse.DoseSummary takenDose = section.getDosesToday().stream()
                .filter(d -> "TAKEN".equals(d.getStatus()))
                .findFirst().orElseThrow();
        assertThat(takenDose.getMedicineName()).isEqualTo("Medicine A");
        assertThat(takenDose.getDoseAmount()).isEqualTo("500");
        assertThat(takenDose.getDoseUnit()).isEqualTo("mg");
        assertThat(takenDose.getTakenAt()).isNotNull();
    }

    @Test
    void getMedicineSummaryHandlesRepositoryExceptionGracefully() {
        when(currentUserProvider.getCurrentUser()).thenThrow(new RuntimeException("DB connection failed"));

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(0);

        assertThat(section.isUnavailable()).isTrue();
        assertThat(section.getError()).isEqualTo("Medicine summary unavailable");
        assertThat(section.getActiveMedicineCount()).isEqualTo(0);
        assertThat(section.getDosesToday()).isNull();
    }

    @Test
    void getMedicineSummaryReturnsEmptyWhenNoDoses() {
        UUID userId = testUser.getId();

        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(0L);
        when(doseRepository.findByUserIdAndScheduledAtBetween(any(), any(), any()))
                .thenReturn(List.of());
        when(doseRepository.countByUserIdAndScheduledAtBetweenAndStatus(any(), any(), any(), any()))
                .thenReturn(0L);

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(0);

        assertThat(section.isUnavailable()).isFalse();
        assertThat(section.getActiveMedicineCount()).isEqualTo(0);
        assertThat(section.getDosesToday()).isEmpty();
        assertThat(section.getDosesTakenToday()).isEqualTo(0);
        assertThat(section.getDosesRemainingToday()).isEqualTo(0);
    }

    @Test
    void getMedicineSummaryHandlesDoseWithoutSchedule() {
        UUID userId = testUser.getId();
        int offsetMinutes = 0;

        OffsetDateTime todayStart = OffsetDateTime.now(ZoneOffset.UTC).withHour(0).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime todayEnd = todayStart.plusDays(1);

        when(medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE)).thenReturn(1L);

        Medicine med = new Medicine();
        med.setId(UUID.randomUUID());
        med.setName("Ad-hoc Medicine");

        DoseRecord dose = new DoseRecord();
        dose.setId(UUID.randomUUID());
        dose.setMedicine(med);
        dose.setSchedule(null); // No schedule
        dose.setStatus(DoseStatus.TAKEN);
        dose.setScheduledAt(todayStart.plusHours(10));
        dose.setTakenAt(todayStart.plusHours(10).plusMinutes(15));

        when(doseRepository.findByUserIdAndScheduledAtBetween(userId, todayStart, todayEnd))
                .thenReturn(List.of(dose));
        when(doseRepository.countByUserIdAndScheduledAtBetweenAndStatus(userId, todayStart, todayEnd, DoseStatus.TAKEN))
                .thenReturn(1L);

        DashboardResponse.MedicineSection section = provider.getMedicineSummary(offsetMinutes);

        assertThat(section.getDosesToday()).hasSize(1);
        DashboardResponse.DoseSummary summary = section.getDosesToday().get(0);
        assertThat(summary.getMedicineName()).isEqualTo("Ad-hoc Medicine");
        assertThat(summary.getScheduleId()).isNull();
        assertThat(summary.getDoseAmount()).isNull();
        assertThat(summary.getDoseUnit()).isNull();
    }
}