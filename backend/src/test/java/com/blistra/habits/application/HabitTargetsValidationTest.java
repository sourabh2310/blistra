package com.blistra.habits.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.HabitRequest;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class HabitTargetsValidationTest {

    private static HabitRequest req(HabitType type, BigDecimal value, String unit, Integer minutes) {
        return HabitRequest.builder().name("Habit").type(type)
                .targetValue(value).targetUnit(unit).targetMinutes(minutes).build();
    }

    @Test
    void booleanAcceptsOnlyNullTargets() {
        assertThatCode(() -> HabitService.validateTargets(
                req(HabitType.BOOLEAN, null, null, null))).doesNotThrowAnyException();
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.BOOLEAN, new BigDecimal("1"), null, null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.BOOLEAN, null, "x", null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.BOOLEAN, null, null, 5)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void countRequiresPositiveValueAndUnitWithoutMinutes() {
        assertThatCode(() -> HabitService.validateTargets(
                req(HabitType.COUNT, new BigDecimal("8"), "glasses", null)))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.COUNT, null, "glasses", null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.COUNT, new BigDecimal("0"), "glasses", null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.COUNT, new BigDecimal("8"), null, null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.COUNT, new BigDecimal("8"), "glasses", 10)))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void durationRequiresPositiveMinutesWithoutValueOrUnit() {
        assertThatCode(() -> HabitService.validateTargets(
                req(HabitType.DURATION, null, null, 20))).doesNotThrowAnyException();
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.DURATION, null, null, null)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.DURATION, null, null, 0)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.DURATION, new BigDecimal("1"), null, 20)))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> HabitService.validateTargets(
                req(HabitType.DURATION, null, "min", 20)))
                .isInstanceOf(BadRequestException.class);
    }
}
