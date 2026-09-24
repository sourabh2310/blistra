package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.medicines.application.MedicineTodayService;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.dto.TodayDoseResponse;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Component
public class MedicineSummaryProvider {

    private final MedicineRepository medicineRepository;
    private final MedicineTodayService medicineTodayService;
    private final CurrentUserProvider currentUserProvider;

    public MedicineSummaryProvider(MedicineRepository medicineRepository,
                                   MedicineTodayService medicineTodayService,
                                   CurrentUserProvider currentUserProvider) {
        this.medicineRepository = medicineRepository;
        this.medicineTodayService = medicineTodayService;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public DashboardResponse.MedicineSection getMedicineSummary(LocalDate date, int offsetMinutes) {
        try {
            var user = currentUserProvider.getCurrentUser();
            long activeMedicineCount = medicineRepository.countByUserIdAndStatus(
                    user.getId(), MedicineStatus.ACTIVE);
            var today = medicineTodayService.getToday(date, offsetMinutes);
            return DashboardResponse.MedicineSection.builder()
                    .activeMedicineCount((int) activeMedicineCount)
                    .dosesToday(mapDoses(today.getDoses()))
                    .dosesTakenToday(today.getTakenDoses())
                    .dosesRemainingToday(today.getRemainingDoses())
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.MedicineSection.builder()
                    .unavailable(true)
                    .error("Medicine summary unavailable")
                    .build();
        }
    }

    private List<DashboardResponse.DoseSummary> mapDoses(List<TodayDoseResponse> doses) {
        if (doses == null) {
            return List.of();
        }
        return doses.stream().map(dose -> DashboardResponse.DoseSummary.builder()
                .id(dose.getDoseRecordId() != null ? dose.getDoseRecordId().toString() : null)
                .medicineId(dose.getMedicineId() != null ? dose.getMedicineId().toString() : null)
                .medicineName(dose.getMedicineName())
                .scheduleId(dose.getScheduleId() != null ? dose.getScheduleId().toString() : null)
                .status(dose.getStatus())
                .scheduledAt(dose.getScheduledAt() != null ? dose.getScheduledAt().toString() : null)
                .takenAt(dose.getTakenAt() != null ? dose.getTakenAt().toString() : null)
                .doseAmount(dose.getDoseAmount())
                .doseUnit(dose.getDoseUnit())
                .build()).toList();
    }
}
