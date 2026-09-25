package com.blistra.medicines.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.dto.PageResponse;
import com.blistra.medicines.domain.DoseRecord;
import com.blistra.medicines.domain.DoseStatus;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicationSchedule;
import com.blistra.medicines.dto.DoseRequest;
import com.blistra.medicines.dto.DoseResponse;
import com.blistra.medicines.dto.DoseUpdateRequest;
import com.blistra.medicines.repository.DoseRecordRepository;
import com.blistra.medicines.repository.MedicationScheduleRepository;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Owns dose records.
 *
 * <p>A dose record is only created when the user records it. The application
 * never auto-marks a dose MISSED. Event instants are stored as offset
 * date-times (UTC-normalized in the database), independent of server-local
 * time.</p>
 */
@Service
@Transactional
public class DoseService {

    private final DoseRecordRepository doseRepository;
    private final MedicineRepository medicineRepository;
    private final MedicationScheduleRepository scheduleRepository;
    private final CurrentUserProvider currentUserProvider;

    public DoseService(DoseRecordRepository doseRepository,
                       MedicineRepository medicineRepository,
                       MedicationScheduleRepository scheduleRepository,
                       CurrentUserProvider currentUserProvider) {
        this.doseRepository = doseRepository;
        this.medicineRepository = medicineRepository;
        this.scheduleRepository = scheduleRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<DoseResponse> list(UUID medicineId, Pageable pageable) {
        requireOwnedMedicine(medicineId);
        UUID userId = currentUserProvider.getCurrentUser().getId();
        Page<DoseRecord> page = doseRepository
                .findAllByMedicineIdAndMedicineUserIdOrderByScheduledAtDesc(medicineId, userId, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public DoseResponse record(UUID medicineId, DoseRequest request) {
        Medicine medicine = requireOwnedMedicine(medicineId);
        OffsetDateTime takenAt = resolveTakenAt(request.getStatus(), request.getTakenAt());
        validateEventTimes(request.getStatus(), request.getScheduledAt(), takenAt);
        rejectDuplicate(medicineId, request);
        DoseRecord record = new DoseRecord(medicine, request.getStatus());
        record.setScheduledAt(request.getScheduledAt());
        record.setTakenAt(takenAt);
        record.setNote(request.getNote());
        if (request.getScheduleId() != null) {
            record.setSchedule(requireOwnedSchedule(request.getScheduleId(), medicineId));
        }
        return toResponse(doseRepository.save(record));
    }

    public DoseResponse update(UUID medicineId, UUID doseId, DoseUpdateRequest request) {
        requireOwnedMedicine(medicineId);
        DoseRecord record = requireOwnedDose(doseId, medicineId);
        OffsetDateTime takenAt = resolveTakenAt(request.getStatus(), request.getTakenAt());
        validateEventTimes(request.getStatus(), record.getScheduledAt(), takenAt);
        record.setStatus(request.getStatus());
        record.setTakenAt(takenAt);
        record.setNote(request.getNote());
        return toResponse(doseRepository.save(record));
    }

    /**
     * Deletes a dose record. This is a corrective action for wrongly entered
     * records; dose history is otherwise preserved.
     */
    public void delete(UUID medicineId, UUID doseId) {
        requireOwnedMedicine(medicineId);
        DoseRecord record = requireOwnedDose(doseId, medicineId);
        doseRepository.delete(record);
    }

    private DoseRecord requireOwnedDose(UUID doseId, UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return doseRepository.findByIdAndMedicineIdAndMedicineUserId(doseId, medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Dose record not found"));
    }

    private Medicine requireOwnedMedicine(UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return medicineRepository.findByIdAndUserId(medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medicine not found"));
    }

    private MedicationSchedule requireOwnedSchedule(UUID scheduleId, UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return scheduleRepository.findByIdAndMedicineIdAndMedicineUserId(scheduleId, medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Schedule not found"));
    }

    /**
     * Minimum accidental-duplicate protection for explicit "take now" taps:
     * recording the same status twice for the same scheduled instant is
     * rejected with 409. Corrections use the update endpoint instead.
     */
    private void rejectDuplicate(UUID medicineId, DoseRequest request) {
        if (request.getScheduledAt() == null) {
            return;
        }
        if (doseRepository.existsByMedicineIdAndScheduledAtAndStatus(
                medicineId, request.getScheduledAt(), request.getStatus())) {
            throw new ResourceAlreadyExistsException(
                    "A " + request.getStatus().name() + " dose is already recorded for this time");
        }
    }

    private OffsetDateTime resolveTakenAt(DoseStatus status, OffsetDateTime supplied) {
        if (status == DoseStatus.TAKEN) {
            return supplied == null ? OffsetDateTime.now() : supplied;
        }
        return supplied;
    }

    private void validateEventTimes(DoseStatus status, OffsetDateTime scheduledAt, OffsetDateTime takenAt) {
        if (status == DoseStatus.TAKEN) {
            if (takenAt.isAfter(OffsetDateTime.now())) {
                throw new BadRequestException("Taken time cannot be in the future");
            }
            if (scheduledAt != null && takenAt.isBefore(scheduledAt)) {
                throw new BadRequestException("Taken time cannot be before the scheduled time");
            }
        } else if (takenAt != null) {
            throw new BadRequestException("A missed or skipped dose cannot have a taken time");
        }
    }

    private DoseResponse toResponse(DoseRecord record) {
        return DoseResponse.builder()
                .id(record.getId())
                .medicineId(record.getMedicine().getId())
                .scheduleId(record.getSchedule() == null ? null : record.getSchedule().getId())
                .status(record.getStatus())
                .scheduledAt(record.getScheduledAt())
                .takenAt(record.getTakenAt())
                .note(record.getNote())
                .createdAt(record.getCreatedAt())
                .updatedAt(record.getUpdatedAt())
                .build();
    }
}