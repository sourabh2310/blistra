package com.blistra.habits.dto;

import com.blistra.habits.domain.HabitType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * A habit with its schedule plus whether it has been completed for a given
 * calendar day. Used by the "today" view.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HabitTodayResponse {

    private UUID id;
    private String name;
    private String description;
    private HabitType type;
    private BigDecimal targetValue;
    private String targetUnit;
    private Integer targetMinutes;
    private ScheduleResponse schedule;
    private boolean completedToday;
}