package com.blistra.medicines.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.medicines.domain.MedicationSchedule;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.ScheduleType;
import com.blistra.medicines.dto.ScheduleRequest;
import com.blistra.medicines.dto.ScheduleResponse;
import com.blistra.medicines.repository.MedicationScheduleRepository;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Owns medication schedules. Schedules are declarative user intent; editing
 * them affects future occurrences only and never rewrites existing dose
 * records (each dose record keeps its own timestamps).
 */
@Service
@Transactional
public class MedicationScheduleService {

    private final MedicationScheduleRepository scheduleRepository;
    private final MedicineRepository medicineRepository;
    private final CurrentUserProvider currentUserProvider;

    public MedicationScheduleService(MedicationScheduleRepository scheduleRepository,
                                     MedicineRepository medicineRepository,
                                     CurrentUserProvider currentUserProvider) {
        this.scheduleRepository = scheduleRepository;
        this.medicineRepository = medicineRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public List<ScheduleResponse> list(UUID medicineId) {
        requireOwnedMedicine(medicineId);
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return scheduleRepository
                .findAllByMedicineIdAndMedicineUserIdOrderByCreatedAtAsc(medicineId, userId)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public ScheduleResponse create(UUID medicineId, ScheduleRequest request) {
        Medicine medicine = requireOwnedMedicine(medicineId);
        validateSchedule(request);
        MedicationSchedule schedule = new MedicationSchedule(medicine, request.getScheduleType());
        applyRequest(schedule, request);
        schedule.setActive(request.getActive() == null || request.getActive());
        return toResponse(scheduleRepository.save(schedule));
    }

    public ScheduleResponse update(UUID medicineId, UUID scheduleId, ScheduleRequest request) {
        requireOwnedMedicine(medicineId);
        validateSchedule(request);
        MedicationSchedule schedule = requireOwnedSchedule(scheduleId, medicineId);
        applyRequest(schedule, request);
        if (request.getActive() != null) {
            schedule.setActive(request.getActive());
        }
        return toResponse(scheduleRepository.save(schedule));
    }

    /**
     * Deleting a schedule preserves dose history: existing dose records keep
     * their scheduled/taken timestamps and simply drop the schedule reference
     * (enforced by the {@code ON DELETE SET NULL} database constraint).
     */
    public void delete(UUID medicineId, UUID scheduleId) {
        requireOwnedMedicine(medicineId);
        MedicationSchedule schedule = requireOwnedSchedule(scheduleId, medicineId);
        scheduleRepository.delete(schedule);
    }

    private MedicationSchedule requireOwnedSchedule(UUID scheduleId, UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return scheduleRepository.findByIdAndMedicineIdAndMedicineUserId(scheduleId, medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Schedule not found"));
    }

    private Medicine requireOwnedMedicine(UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return medicineRepository.findByIdAndUserId(medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medicine not found"));
    }

    private void validateSchedule(ScheduleRequest request) {
        List<LocalTime> times = parseTimes(request.getTimes());
        ScheduleType type = request.getScheduleType();
        boolean needsDays = type == ScheduleType.WEEKLY || type == ScheduleType.CUSTOM_DAYS;
        if (needsDays && (request.getDaysOfWeek() == null || request.getDaysOfWeek().isEmpty())) {
            throw new BadRequestException("At least one day of the week is required for weekly schedules");
        }
        if (type == ScheduleType.AS_NEEDED && !times.isEmpty()) {
            throw new BadRequestException("As-needed schedules cannot declare fixed times");
        }
        if (request.getStartDate() != null && request.getEndDate() != null
                && request.getEndDate().isBefore(request.getStartDate())) {
            throw new BadRequestException("End date must not be before the start date");
        }
    }

    private List<LocalTime> parseTimes(List<String> raw) {
        List<LocalTime> times = new ArrayList<>();
        if (raw == null || raw.isEmpty()) {
            return times;
        }
        for (String value : raw) {
            String trimmed = value == null ? "" : value.trim();
            try {
                times.add(LocalTime.parse(trimmed));
            } catch (DateTimeParseException e) {
                throw new BadRequestException("Invalid time format '" + value + "'; expected HH:mm");
            }
        }
        return times;
    }

    private void applyRequest(MedicationSchedule schedule, ScheduleRequest request) {
        schedule.setScheduleType(request.getScheduleType());
        schedule.setTimes(parseTimes(request.getTimes()));
        schedule.setDaysOfWeek(request.getDaysOfWeek() == null ? new ArrayList<>() : request.getDaysOfWeek());
        schedule.setDoseAmount(request.getDoseAmount());
        schedule.setDoseUnit(request.getDoseUnit());
        schedule.setStartDate(request.getStartDate());
        schedule.setEndDate(request.getEndDate());
    }

    private ScheduleResponse toResponse(MedicationSchedule schedule) {
        return ScheduleResponse.builder()
                .id(schedule.getId())
                .medicineId(schedule.getMedicine().getId())
                .scheduleType(schedule.getScheduleType())
                .times(schedule.getTimes())
                .daysOfWeek(schedule.getDaysOfWeek())
                .doseAmount(schedule.getDoseAmount())
                .doseUnit(schedule.getDoseUnit())
                .startDate(schedule.getStartDate())
                .endDate(schedule.getEndDate())
                .active(schedule.isActive())
                .createdAt(schedule.getCreatedAt())
                .updatedAt(schedule.getUpdatedAt())
                .build();
    }
}