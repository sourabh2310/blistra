package com.blistra.health.application;

import com.blistra.common.exception.InvalidRequestException;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.dto.MeasurementRequest;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.Locale;

/**
 * Domain validation for measurements.
 *
 * Bean validation on the DTO covers required fields and positivity. This class
 * enforces cross-field and type-specific rules with generous ranges that reject
 * only obviously impossible values. It never produces medical interpretation.
 */
@Component
public class MeasurementValidator {

    private static final BigDecimal MIN_WEIGHT_KG = new BigDecimal("5");
    private static final BigDecimal MAX_WEIGHT_KG = new BigDecimal("400");
    private static final BigDecimal MIN_WEIGHT_LB = new BigDecimal("10");
    private static final BigDecimal MAX_WEIGHT_LB = new BigDecimal("900");

    private static final BigDecimal MIN_HEIGHT_CM = new BigDecimal("50");
    private static final BigDecimal MAX_HEIGHT_CM = new BigDecimal("250");
    private static final BigDecimal MIN_HEIGHT_IN = new BigDecimal("20");
    private static final BigDecimal MAX_HEIGHT_IN = new BigDecimal("98");

    private static final BigDecimal MIN_HR = new BigDecimal("20");
    private static final BigDecimal MAX_HR = new BigDecimal("300");

    private static final BigDecimal MIN_TEMP_C = new BigDecimal("30");
    private static final BigDecimal MAX_TEMP_C = new BigDecimal("45");
    private static final BigDecimal MIN_TEMP_F = new BigDecimal("86");
    private static final BigDecimal MAX_TEMP_F = new BigDecimal("113");

    private static final BigDecimal MIN_SYSTOLIC = new BigDecimal("60");
    private static final BigDecimal MAX_SYSTOLIC = new BigDecimal("280");
    private static final BigDecimal MIN_DIASTOLIC = new BigDecimal("30");
    private static final BigDecimal MAX_DIASTOLIC = new BigDecimal("200");

    public void validate(MeasurementRequest request) {
        MeasurementType type = request.getType();
        String unit = request.getUnit() == null ? "" : request.getUnit().toUpperCase(Locale.ROOT);

        switch (type) {
            case WEIGHT -> validateRange(request.getValue(), minWeight(unit), maxWeight(unit),
                    "Weight value is outside a plausible range for unit " + unit, unit, "KG", "LB");
            case HEIGHT -> validateRange(request.getValue(), minHeight(unit), maxHeight(unit),
                    "Height value is outside a plausible range for unit " + unit, unit, "CM", "IN");
            case HEART_RATE -> validateRange(request.getValue(), MIN_HR, MAX_HR,
                    "Heart rate value is outside a plausible range", unit, "BPM");
            case TEMPERATURE -> validateRange(request.getValue(), minTemp(unit), maxTemp(unit),
                    "Temperature value is outside a plausible range for unit " + unit, unit, "C", "F");
            case BLOOD_PRESSURE -> validateBloodPressure(request, unit);
        }
    }

    private void validateBloodPressure(MeasurementRequest request, String unit) {
        if (!"MMHG".equals(unit)) {
            throw new InvalidRequestException("Unit MMHG is required for blood pressure measurements");
        }
        BigDecimal diastolic = request.getValueDiastolic();
        if (diastolic == null) {
            throw new InvalidRequestException("Diastolic value is required for blood pressure measurements");
        }
        BigDecimal systolic = request.getValue();
        validateRange(systolic, MIN_SYSTOLIC, MAX_SYSTOLIC,
                "Systolic value is outside a plausible range", unit, "MMHG");
        validateRange(diastolic, MIN_DIASTOLIC, MAX_DIASTOLIC,
                "Diastolic value is outside a plausible range", unit, "MMHG");
        if (systolic.compareTo(diastolic) <= 0) {
            throw new InvalidRequestException("Systolic must be greater than diastolic");
        }
    }

    private void validateRange(BigDecimal value, BigDecimal min, BigDecimal max, String message,
                               String unit, String... allowedUnits) {
        boolean unitOk = false;
        for (String allowed : allowedUnits) {
            if (allowed.equals(unit)) {
                unitOk = true;
                break;
            }
        }
        if (!unitOk) {
            throw new InvalidRequestException("Unit " + unit + " is not valid for this measurement type");
        }
        if (value.compareTo(min) < 0 || value.compareTo(max) > 0) {
            throw new InvalidRequestException(message);
        }
    }

    private static BigDecimal minWeight(String unit) {
        return "LB".equals(unit) ? MIN_WEIGHT_LB : MIN_WEIGHT_KG;
    }

    private static BigDecimal maxWeight(String unit) {
        return "LB".equals(unit) ? MAX_WEIGHT_LB : MAX_WEIGHT_KG;
    }

    private static BigDecimal minHeight(String unit) {
        return "IN".equals(unit) ? MIN_HEIGHT_IN : MIN_HEIGHT_CM;
    }

    private static BigDecimal maxHeight(String unit) {
        return "IN".equals(unit) ? MAX_HEIGHT_IN : MAX_HEIGHT_CM;
    }

    private static BigDecimal minTemp(String unit) {
        return "F".equals(unit) ? MIN_TEMP_F : MIN_TEMP_C;
    }

    private static BigDecimal maxTemp(String unit) {
        return "F".equals(unit) ? MAX_TEMP_F : MAX_TEMP_C;
    }
}