package com.blistra.medicines.dto;

import com.blistra.medicines.domain.ScheduleType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

/**
 * Schedule representation returned to clients.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScheduleResponse {

    private UUID id;
    private UUID medicineId;
    private ScheduleType scheduleType;
    private List<LocalTime> times;
    private List<DayOfWeek> daysOfWeek;
    private BigDecimal doseAmount;
    private String doseUnit;
    private LocalDate startDate;
    private LocalDate endDate;
    private boolean active;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}