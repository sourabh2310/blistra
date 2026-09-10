package com.blistra.medicines.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.dto.PageResponse;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.dto.MedicineRequest;
import com.blistra.medicines.dto.MedicineResponse;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Owns medicine CRUD. Every operation is scoped to the authenticated user.
 */
@Service
@Transactional
public class MedicineService {

    private final MedicineRepository medicineRepository;
    private final CurrentUserProvider currentUserProvider;

    public MedicineService(MedicineRepository medicineRepository, CurrentUserProvider currentUserProvider) {
        this.medicineRepository = medicineRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<MedicineResponse> list(MedicineStatus status, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<Medicine> page = status == null
                ? medicineRepository.findAllByUserIdAndStatusNotOrderByCreatedAtDesc(
                        user.getId(), MedicineStatus.ARCHIVED, pageable)
                : medicineRepository.findAllByUserIdAndStatusOrderByCreatedAtDesc(user.getId(), status, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public MedicineResponse create(MedicineRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Medicine medicine = new Medicine(user, request.getName());
        applyRequest(medicine, request);
        medicine.setStatus(request.getStatus() == null ? MedicineStatus.ACTIVE : request.getStatus());
        return toResponse(medicineRepository.save(medicine));
    }

    @Transactional(readOnly = true)
    public MedicineResponse get(UUID id) {
        return toResponse(getOwned(id));
    }

    public MedicineResponse update(UUID id, MedicineRequest request) {
        Medicine medicine = getOwned(id);
        applyRequest(medicine, request);
        if (request.getStatus() != null) {
            medicine.setStatus(request.getStatus());
        }
        return toResponse(medicineRepository.save(medicine));
    }

    /**
     * Deletion is implemented as archiving: the medicine is hidden from active
     * lists while its historical dose and refill records remain meaningful.
     */
    public void archive(UUID id) {
        Medicine medicine = getOwned(id);
        medicine.setStatus(MedicineStatus.ARCHIVED);
        medicineRepository.save(medicine);
    }

    private Medicine getOwned(UUID id) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return medicineRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medicine not found"));
    }

    private void applyRequest(Medicine medicine, MedicineRequest request) {
        medicine.setName(request.getName());
        medicine.setGenericName(request.getGenericName());
        medicine.setForm(request.getForm());
        medicine.setStrength(request.getStrength());
        medicine.setStrengthUnit(request.getStrengthUnit());
        medicine.setNotes(request.getNotes());
        medicine.setStartDate(request.getStartDate());
        medicine.setEndDate(request.getEndDate());
    }

    private MedicineResponse toResponse(Medicine medicine) {
        return MedicineResponse.builder()
                .id(medicine.getId())
                .name(medicine.getName())
                .genericName(medicine.getGenericName())
                .form(medicine.getForm())
                .strength(medicine.getStrength())
                .strengthUnit(medicine.getStrengthUnit())
                .notes(medicine.getNotes())
                .status(medicine.getStatus())
                .startDate(medicine.getStartDate())
                .endDate(medicine.getEndDate())
                .createdAt(medicine.getCreatedAt())
                .updatedAt(medicine.getUpdatedAt())
                .build();
    }
}