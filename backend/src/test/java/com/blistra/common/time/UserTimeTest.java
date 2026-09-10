package com.blistra.common.time;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Regression tests for the authoritative user-timezone foundation.
 */
class UserTimeTest {

    @Test
    void defaultsToKolkata() {
        UserTime userTime = new UserTime("Asia/Kolkata");

        assertThat(userTime.zone()).isEqualTo(ZoneId.of("Asia/Kolkata"));
        assertThat(userTime.today()).isEqualTo(LocalDate.now(ZoneId.of("Asia/Kolkata")));
    }

    @Test
    void honorsConfiguredZone() {
        UserTime userTime = new UserTime("Pacific/Auckland");

        assertThat(userTime.zone()).isEqualTo(ZoneId.of("Pacific/Auckland"));
        assertThat(userTime.today()).isEqualTo(LocalDate.now(ZoneId.of("Pacific/Auckland")));
    }

    @Test
    void nowCarriesZoneOffset() {
        UserTime userTime = new UserTime("Asia/Kolkata");

        assertThat(userTime.now().getOffset())
                .isEqualTo(ZoneId.of("Asia/Kolkata").getRules().getOffset(userTime.now().toInstant()));
    }

    @Test
    void invalidZoneFailsFast() {
        assertThatThrownBy(() -> new UserTime("Not/AZone"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("blistra.user-timezone");
    }
}
