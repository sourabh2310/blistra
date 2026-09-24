package com.blistra.preferences.application;

import com.blistra.common.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Pure validation tests for Home/navigation preference rules: allowlists,
 * mandatory HOME/ADD, max 5 destinations, locked Day-at-a-glance hero.
 */
class AppPreferencesValidationTest {

    @Test
    void defaultNavIsValid() {
        assertThat(AppPreferencesService.normalizeNav(AppPreferencesService.DEFAULT_NAV))
                .containsExactly("HOME", "PLANNER", "ADD", "HEALTH", "HUB");
    }

    @Test
    void defaultWidgetsKeepHeroFirst() {
        assertThat(AppPreferencesService.normalizeWidgets(AppPreferencesService.DEFAULT_WIDGETS).get(0))
                .isEqualTo("DAY_AT_A_GLANCE");
    }

    @Test
    void homeCannotBeRemoved() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(List.of("PLANNER", "ADD", "HUB")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("HOME");
    }

    @Test
    void addCannotBeRemoved() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(List.of("HOME", "PLANNER", "HUB")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("ADD");
    }

    @Test
    void maxFiveNavItems() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(
                List.of("HOME", "PLANNER", "ADD", "HEALTH", "HUB", "DIET")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("5");
    }

    @Test
    void unknownDestinationRejected() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(
                List.of("HOME", "ADD", "ADMIN")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("ADMIN");
    }

    @Test
    void unknownWidgetRejected() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeWidgets(
                List.of("DAY_AT_A_GLANCE", "FAKE_FEATURE")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("FAKE_FEATURE");
    }

    @Test
    void heroPrependedWhenMissing() {
        assertThat(AppPreferencesService.normalizeWidgets(List.of("HEALTH", "DIET")).get(0))
                .isEqualTo("DAY_AT_A_GLANCE");
    }

    @Test
    void identifiersNormalizedCaseInsensitive() {
        assertThat(AppPreferencesService.normalizeNav(List.of(" home ", "add", "hub")))
                .containsExactly("HOME", "ADD", "HUB");
    }
}
