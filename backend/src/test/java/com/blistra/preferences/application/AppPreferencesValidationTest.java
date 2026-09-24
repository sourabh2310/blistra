package com.blistra.preferences.application;

import com.blistra.common.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AppPreferencesValidationTest {

    @Test
    void defaultNavIsExact() {
        assertThat(AppPreferencesService.normalizeNav(AppPreferencesService.DEFAULT_NAV))
                .containsExactly("HOME", "PLANNER", "ADD", "HUB", "HEALTH");
    }

    @Test
    void defaultWidgetsHaveExactContractAndOrder() {
        assertThat(AppPreferencesService.normalizeWidgets(AppPreferencesService.DEFAULT_WIDGETS))
                .containsExactly("TODAY_OVERVIEW", "TODAYS_SCHEDULE", "NEEDS_ATTENTION",
                        "YOUR_LIFE", "THIS_WEEK", "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE");
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
    void maxFiveUniqueNavItems() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(
                List.of("HOME", "PLANNER", "ADD", "HEALTH", "HUB", "DIET")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("5");
        assertThat(AppPreferencesService.normalizeNav(
                List.of("HOME", "HOME", "PLANNER", "ADD", "HEALTH", "HUB", "HUB")))
                .containsExactly("HOME", "PLANNER", "ADD", "HEALTH", "HUB");
    }

    @Test
    void unknownDestinationRejected() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(
                List.of("HOME", "ADD", "ADMIN")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("ADMIN");
        assertThatThrownBy(() -> AppPreferencesService.normalizeNav(
                List.of("HOME", "ADD", "PROFILE")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("PROFILE");
    }

    @Test
    void unknownWidgetRejected() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeWidgets(
                List.of("TODAY_OVERVIEW", "FAKE_FEATURE")))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("FAKE_FEATURE");
    }

    @Test
    void homeCannotBeEmpty() {
        assertThatThrownBy(() -> AppPreferencesService.normalizeWidgets(List.of()))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("at least one");
        assertThatThrownBy(() -> AppPreferencesService.normalizeWidgets(Arrays.asList(" ", null)))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("at least one");
    }

    @Test
    void widgetOrderAndDuplicatesArePreserved() {
        assertThat(AppPreferencesService.normalizeWidgets(
                List.of("this_week", "medicines", "today_overview", "medicines")))
                .containsExactly("THIS_WEEK", "YOUR_LIFE", "MEDICINES", "TODAY_OVERVIEW");
    }

    @Test
    void selectedModulesMakeLifeSectionVisible() {
        assertThat(AppPreferencesService.normalizeWidgets(
                List.of("TODAYS_SCHEDULE", "FINANCE", "DIET")))
                .containsExactly("TODAYS_SCHEDULE", "YOUR_LIFE", "FINANCE", "DIET");
    }

    @Test
    void identifiersNormalizedCaseInsensitive() {
        assertThat(AppPreferencesService.normalizeNav(List.of(" home ", "add", "hub")))
                .containsExactly("HOME", "ADD", "HUB");
        assertThat(AppPreferencesService.normalizeWidgets(List.of(" this_week ")))
                .containsExactly("THIS_WEEK");
    }

    @Test
    void legacyStoredWidgetsAreNormalized() {
        assertThat(AppPreferencesService.normalizeStoredWidgets(
                "DAY_AT_A_GLANCE,MEDICINES,FINANCE"))
                .containsExactly("TODAY_OVERVIEW", "YOUR_LIFE", "MEDICINES", "FINANCE");
        assertThat(AppPreferencesService.normalizeStoredWidgets(
                "DAY_AT_A_GLANCE,HEALTH,MEDICINES,DIET,HABITS,PLANNER,FINANCE"))
                .containsExactly("TODAY_OVERVIEW", "TODAYS_SCHEDULE", "NEEDS_ATTENTION",
                        "YOUR_LIFE", "THIS_WEEK", "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE");
    }

    @Test
    void unknownStoredValuesFallBackWithoutBreakingRead() {
        assertThat(AppPreferencesService.normalizeStoredWidgets("OLD_PROFILE,FAKE"))
                .isEqualTo(AppPreferencesService.DEFAULT_WIDGETS);
        assertThat(AppPreferencesService.normalizeStoredNav("PROFILE,HUB"))
                .containsExactly("HOME", "ADD", "HUB");
    }
}
