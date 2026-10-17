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
    void authenticatedProfileZoneOverridesServerAndChangesBetweenUsers() {
        var context=org.springframework.security.core.context.SecurityContextHolder.getContext();
        try {
            var principal=new com.blistra.auth.security.BlistraUserPrincipal(java.util.UUID.randomUUID(),
                    "user@example.com","hash",java.util.List.of()).withTimezone("America/New_York");
            context.setAuthentication(new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(principal,null,principal.getAuthorities()));
            var time=new UserTime("Asia/Kolkata");
            assertThat(time.zone()).isEqualTo(ZoneId.of("America/New_York"));
            var spring=LocalDate.of(2026,3,8);
            assertThat(java.time.Duration.between(spring.atStartOfDay(time.zone()),spring.plusDays(1).atStartOfDay(time.zone())).toHours()).isEqualTo(23);
            principal.withTimezone("Pacific/Auckland");
            assertThat(time.zone()).isEqualTo(ZoneId.of("Pacific/Auckland"));
        } finally { org.springframework.security.core.context.SecurityContextHolder.clearContext(); }
    }

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
