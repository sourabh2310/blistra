package com.blistra.medicines.application;

import com.blistra.common.time.UserTime;
import com.blistra.medicines.domain.DoseRecord;
import com.blistra.medicines.domain.DoseStatus;
import com.blistra.medicines.domain.MedicationSchedule;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.domain.ScheduleType;
import com.blistra.medicines.dto.MedicineTodayResponse;
import com.blistra.medicines.dto.TodayDoseResponse;
import com.blistra.medicines.repository.DoseRecordRepository;
import com.blistra.medicines.repository.MedicationScheduleRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Expands the user's active medication schedules into expected dose
 * occurrences for one calendar day and matches them against recorded dose
 * records.
 *
 * <p>Design rules (mirroring the domain invariants):</p>
 * <ul>
 *   <li>Only {@code ACTIVE} medicines with {@code active} schedules generate
 *       expectations. {@code AS_NEEDED} schedules declare no fixed times and
 *       therefore generate none.</li>
 *   <li>A slot is {@code PENDING} until the user records it. The server never
 *       invents {@code MISSED} — a missed dose is only a user-recorded one.</li>
 *   <li>Record matching is by exact scheduled instant (plus schedule id when
 *       the record carries one). Ad-hoc records whose instant matches no slot
 *       stay in per-medicine history and do not inflate today's totals.</li>
 * </ul>
 */
@Service
@Transactional(readOnly = true)
public class MedicineTodayService {

    private final MedicationScheduleRepository scheduleRepository;
    private final DoseRecordRepository doseRepository;
    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;

    public MedicineTodayService(MedicationScheduleRepository scheduleRepository,
                                DoseRecordRepository doseRepository,
                                CurrentUserProvider currentUserProvider,
                                UserTime userTime) {
        this.scheduleRepository = scheduleRepository;
        this.doseRepository = doseRepository;
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
    }

    public MedicineTodayResponse getToday(LocalDate date, Integer offsetMinutes) {
        User user = currentUserProvider.getCurrentUser();
        ZoneId zone = offsetMinutes != null
                ? ZoneOffset.ofTotalSeconds(offsetMinutes * 60)
                : userTime.zone();
        LocalDate effectiveDate = date != null ? date : LocalDate.now(zone);
        OffsetDateTime start = effectiveDate.atStartOfDay(zone).toOffsetDateTime();
        OffsetDateTime end = effectiveDate.plusDays(1).atStartOfDay(zone).toOffsetDateTime();
        OffsetDateTime now = OffsetDateTime.now(zone);

        List<MedicationSchedule> schedules = scheduleRepository.findActiveByUserId(user.getId());
        List<DoseRecord> records = doseRepository.findByUserIdAndScheduledAtBetween(user.getId(), start, end);
        Map<UUID, List<DoseRecord>> recordsByMedicine = records.stream()
                .collect(Collectors.groupingBy(r -> r.getMedicine().getId()));

        List<TodayDoseResponse> doses = new ArrayList<>();
        for (MedicationSchedule schedule : schedules) {
            Medicine medicine = schedule.getMedicine();
            if (medicine.getStatus() != MedicineStatus.ACTIVE) {
                continue;
            }
            if (!withinWindow(schedule, effectiveDate)) {
                continue;
            }
            if (!appliesToday(schedule, effectiveDate.getDayOfWeek())) {
                continue;
            }
            List<DoseRecord> candidates =
                    recordsByMedicine.getOrDefault(medicine.getId(), List.of());
            for (LocalTime time : schedule.getTimes()) {
                OffsetDateTime slot =
                        LocalDateTime.of(effectiveDate, time).atZone(zone).toOffsetDateTime();
                doses.add(toDose(medicine, schedule, slot, matchRecord(candidates, schedule.getId(), slot)));
            }
        }
        doses.sort(Comparator.comparing(TodayDoseResponse::getScheduledAt));

        int taken = 0;
        int missed = 0;
        int skipped = 0;
        for (TodayDoseResponse dose : doses) {
            switch (dose.getStatus()) {
                case "TAKEN" -> taken++;
                case "MISSED" -> missed++;
                case "SKIPPED" -> skipped++;
                default -> {
                }
            }
        }
        TodayDoseResponse next = doses.stream()
                .filter(d -> "PENDING".equals(d.getStatus()) && !d.getScheduledAt().isBefore(now))
                .findFirst()
                .orElse(null);

        return MedicineTodayResponse.builder()
                .date(effectiveDate)
                .totalDoses(doses.size())
                .takenDoses(taken)
                .remainingDoses(doses.size() - taken - missed - skipped)
                .missedDoses(missed)
                .skippedDoses(skipped)
                .nextDose(next)
                .doses(doses)
                .build();
    }

    private boolean withinWindow(MedicationSchedule schedule, LocalDate date) {
        if (schedule.getStartDate() != null && date.isBefore(schedule.getStartDate())) {
            return false;
        }
        return schedule.getEndDate() == null || !date.isAfter(schedule.getEndDate());
    }

    private boolean appliesToday(MedicationSchedule schedule, DayOfWeek day) {
        ScheduleType type = schedule.getScheduleType();
        if (type == ScheduleType.AS_NEEDED) {
            return false;
        }
        if (type == ScheduleType.WEEKLY || type == ScheduleType.CUSTOM_DAYS) {
            return schedule.getDaysOfWeek() != null && schedule.getDaysOfWeek().contains(day);
        }
        return true;
    }

    private DoseRecord matchRecord(List<DoseRecord> candidates, UUID scheduleId, OffsetDateTime slot) {
        DoseRecord fallback = null;
        for (DoseRecord record : candidates) {
            if (record.getScheduledAt() == null
                    || !record.getScheduledAt().toInstant().equals(slot.toInstant())) {
                continue;
            }
            if (record.getSchedule() != null && !record.getSchedule().getId().equals(scheduleId)) {
                continue;
            }
            if (record.getStatus() == DoseStatus.TAKEN) {
                return record;
            }
            fallback = record;
        }
        return fallback;
    }

    private TodayDoseResponse toDose(Medicine medicine, MedicationSchedule schedule,
                                     OffsetDateTime slot, DoseRecord record) {
        return TodayDoseResponse.builder()
                .medicineId(medicine.getId())
                .medicineName(medicine.getName())
                .scheduleId(schedule.getId())
                .scheduledAt(slot)
                .status(record == null ? "PENDING" : record.getStatus().name())
                .takenAt(record == null ? null : record.getTakenAt())
                .doseAmount(schedule.getDoseAmount() != null
                        ? schedule.getDoseAmount().toPlainString() : null)
                .doseUnit(schedule.getDoseUnit())
                .doseRecordId(record == null ? null : record.getId())
                .build();
    }
}
