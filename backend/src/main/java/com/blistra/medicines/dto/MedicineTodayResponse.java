package com.blistra.medicines.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

/**
 * Expected doses for one user-local calendar day, expanded from the user's
 * active medicines and active schedules and matched against recorded dose
 * records. Medicines own this data; planners/dashboards only aggregate it.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MedicineTodayResponse {

    private LocalDate date;
    private int totalDoses;
    private int takenDoses;
    private int remainingDoses;
    private int missedDoses;
    private int skippedDoses;
    private TodayDoseResponse nextDose;
    private List<TodayDoseResponse> doses;
}
