package com.blistra.medicines.dto;

import com.blistra.medicines.domain.MedicineStatus;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import jakarta.validation.constraints.AssertTrue;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Create/update payload for a {@link com.blistra.medicines.domain.Medicine}.
 *
 * <p>Ownership fields (user id) and audit timestamps are never accepted from
 * the client.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MedicineRequest {

    @NotBlank(message = "Name is required")
    @Size(max = 100, message = "Name must be at most 100 characters")
    private String name;

    @Size(max = 100, message = "Generic name must be at most 100 characters")
    private String genericName;

    @Size(max = 50, message = "Form must be at most 50 characters")
    private String form;

    @DecimalMin(value = "0.0", message = "Strength cannot be negative")
    @Digits(integer = 12, fraction = 4, message = "Strength has too many digits")
    private BigDecimal strength;

    @Size(max = 25, message = "Strength unit must be at most 25 characters")
    private String strengthUnit;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;

    private MedicineStatus status;

    private LocalDate startDate;

    private LocalDate endDate;

    @AssertTrue(message = "End date must not be before the start date")
    public boolean isDatesValid() {
        return startDate == null || endDate == null || !endDate.isBefore(startDate);
    }
}