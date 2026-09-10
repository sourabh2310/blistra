package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.medicines.domain.DoseRecord;
import com.blistra.medicines.domain.DoseStatus;
import com.blistra.medicines.domain.MedicationSchedule;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.repository.DoseRecordRepository;
import com.blistra.medicines.repository.MedicationScheduleRepository;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Dashboard-internal adapter that reads Medicine data for aggregation.
 *
 * <p>This is part of the Dashboard module, not the Medicines module. It uses
 * Medicines' repositories directly for read-only summary queries, avoiding
 * duplicate business logic while keeping the Dashboard as a pure aggregation layer.</p>
 */
@Component
public class MedicineSummaryProvider {

    private final MedicineRepository medicineRepository;
    private final MedicationScheduleRepository scheduleRepository;
    private final DoseRecordRepository doseRepository;
    private final CurrentUserProvider currentUserProvider;

    public MedicineSummaryProvider(MedicineRepository medicineRepository,
                                    MedicationScheduleRepository scheduleRepository,
                                    DoseRecordRepository doseRepository,
                                    CurrentUserProvider currentUserProvider) {
        this.medicineRepository = medicineRepository;
        this.scheduleRepository = scheduleRepository;
        this.doseRepository = doseRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public DashboardResponse.MedicineSection getMedicineSummary(int offsetMinutes) {
        try {
            var user = currentUserProvider.getCurrentUser();
            UUID userId = user.getId();

            // Define today's range in user's local time (like Diet does)
            ZoneOffset offset = ZoneOffset.ofTotalSeconds(offsetMinutes * 60);
            OffsetDateTime todayStart = OffsetDateTime.now(offset).withHour(0).withMinute(0).withSecond(0).withNano(0);
            OffsetDateTime todayEnd = todayStart.plusDays(1);

            // Active medicine count
            long activeMedicineCount = medicineRepository.countByUserIdAndStatus(userId, MedicineStatus.ACTIVE);

            // Today's doses from dose records
            List<DoseRecord> todayDoses = doseRepository.findByUserIdAndScheduledAtBetween(userId, todayStart, todayEnd);

            // Counts
            long dosesTakenToday = doseRepository.countByUserIdAndScheduledAtBetweenAndStatus(
                    userId, todayStart, todayEnd, DoseStatus.TAKEN);
            long dosesRemainingToday = todayDoses.size() - dosesTakenToday;

            // Build dose summaries
            List<DashboardResponse.DoseSummary> doseSummaries = new ArrayList<>();
            for (DoseRecord dose : todayDoses) {
                Medicine medicine = dose.getMedicine();
                MedicationSchedule schedule = dose.getSchedule();

                doseSummaries.add(DashboardResponse.DoseSummary.builder()
                        .id(dose.getId().toString())
                        .medicineId(medicine.getId().toString())
                        .medicineName(medicine.getName())
                        .scheduleId(schedule != null ? schedule.getId().toString() : null)
                        .status(dose.getStatus().name())
                        .scheduledAt(dose.getScheduledAt().toString())
                        .takenAt(dose.getTakenAt() != null ? dose.getTakenAt().toString() : null)
                        .doseAmount(schedule != null && schedule.getDoseAmount() != null
                                ? schedule.getDoseAmount().toPlainString() : null)
                        .doseUnit(schedule != null ? schedule.getDoseUnit() : null)
                        .build());
            }

            return DashboardResponse.MedicineSection.builder()
                    .activeMedicineCount((int) activeMedicineCount)
                    .dosesToday(doseSummaries)
                    .dosesTakenToday((int) dosesTakenToday)
                    .dosesRemainingToday((int) dosesRemainingToday)
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.MedicineSection.builder()
                    .unavailable(true)
                    .error("Medicine summary unavailable")
                    .build();
        }
    }
}