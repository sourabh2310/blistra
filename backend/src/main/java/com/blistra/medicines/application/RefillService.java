package com.blistra.medicines.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.dto.PageResponse;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.domain.Refill;
import com.blistra.medicines.dto.RefillRequest;
import com.blistra.medicines.dto.RefillResponse;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.medicines.repository.RefillRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Owns refill records. Refills are informational user records; the application
 * does not place orders or manage prescriptions.
 */
@Service
@Transactional
public class RefillService {

    private final RefillRepository refillRepository;
    private final MedicineRepository medicineRepository;
    private final CurrentUserProvider currentUserProvider;

    public RefillService(RefillRepository refillRepository,
                         MedicineRepository medicineRepository,
                         CurrentUserProvider currentUserProvider) {
        this.refillRepository = refillRepository;
        this.medicineRepository = medicineRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<RefillResponse> list(UUID medicineId, Pageable pageable) {
        requireOwnedMedicine(medicineId);
        UUID userId = currentUserProvider.getCurrentUser().getId();
        Page<Refill> page = refillRepository
                .findAllByMedicineIdAndMedicineUserIdOrderByRefillDateDesc(medicineId, userId, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public RefillResponse create(UUID medicineId, RefillRequest request) {
        Medicine medicine = requireOwnedMedicine(medicineId);
        validateRefillDate(request.getRefillDate());
        Refill refill = new Refill(medicine, request.getRefillDate(), request.getQuantity());
        refill.setRemainingQuantity(request.getRemainingQuantity());
        refill.setNotes(request.getNotes());
        return toResponse(refillRepository.save(refill));
    }

    public RefillResponse update(UUID medicineId, UUID refillId, RefillRequest request) {
        requireOwnedMedicine(medicineId);
        validateRefillDate(request.getRefillDate());
        Refill refill = requireOwnedRefill(refillId, medicineId);
        refill.setRefillDate(request.getRefillDate());
        refill.setQuantity(request.getQuantity());
        refill.setRemainingQuantity(request.getRemainingQuantity());
        refill.setNotes(request.getNotes());
        return toResponse(refillRepository.save(refill));
    }

    public void delete(UUID medicineId, UUID refillId) {
        requireOwnedMedicine(medicineId);
        Refill refill = requireOwnedRefill(refillId, medicineId);
        refillRepository.delete(refill);
    }

    private Refill requireOwnedRefill(UUID refillId, UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return refillRepository.findByIdAndMedicineIdAndMedicineUserId(refillId, medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Refill not found"));
    }

    private Medicine requireOwnedMedicine(UUID medicineId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return medicineRepository.findByIdAndUserId(medicineId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Medicine not found"));
    }

    private void validateRefillDate(LocalDate refillDate) {
        if (refillDate.isAfter(LocalDate.now().plusYears(1))) {
            throw new BadRequestException("Refill date cannot be more than one year in the future");
        }
    }

    private RefillResponse toResponse(Refill refill) {
        return RefillResponse.builder()
                .id(refill.getId())
                .medicineId(refill.getMedicine().getId())
                .refillDate(refill.getRefillDate())
                .quantity(refill.getQuantity())
                .remainingQuantity(refill.getRemainingQuantity())
                .notes(refill.getNotes())
                .createdAt(refill.getCreatedAt())
                .updatedAt(refill.getUpdatedAt())
                .build();
    }
}