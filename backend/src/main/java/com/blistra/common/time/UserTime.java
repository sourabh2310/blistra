package com.blistra.common.time;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;

/**
 * The single authoritative timezone source for user-facing calendar semantics.
 *
 * <p>Every "today", "upcoming", "overdue", date-default and day-boundary
 * calculation in application services must derive the zone from here — never
 * from the server-local zone ({@code LocalDate.now()},
 * {@code OffsetDateTime.now()}) and never from a stored numeric offset.</p>
 *
 * <p>Design contract (V1):
 * <ul>
 *   <li>The zone is a real IANA {@link ZoneId} (default {@code Asia/Kolkata}),
 *       so DST transitions are handled by the {@code java.time} rules instead
 *       of manual arithmetic.</li>
 *   <li>Client-supplied {@code offsetMinutes} values are request-scoped
 *       <em>hints</em> for drawing one calendar-day window; they are the
 *       client's <em>current</em> offset, never stored, so they cannot go stale
 *       across DST changes. All persisted moments stay UTC
 *       ({@code TIMESTAMPTZ} / {@code DATE} in UTC terms).</li>
 *   <li>Day windows are half-open {@code [start, end)} so a row exactly at
 *       midnight belongs to exactly one day.</li>
 *   <li>The planned upgrade is a per-user IANA zone (e.g. a
 *       {@code users.timezone} column); this bean is the seam where that
 *       lookup will plug in, behind the same {@link #zone()} API.</li>
 * </ul>
 */
@Component
public class UserTime {

    private final ZoneId userZone;

    public UserTime(
            @Value("${blistra.user-timezone:${planner.user-timezone:Asia/Kolkata}}") String userTimezone) {
        try {
            this.userZone = ZoneId.of(userTimezone);
        } catch (Exception e) {
            throw new IllegalStateException("Invalid blistra.user-timezone: " + userTimezone, e);
        }
    }

    /**
     * The authoritative zone for user calendar semantics.
     */
    public ZoneId zone() {
        return userZone;
    }

    /**
     * Today's calendar date in the user zone.
     */
    public LocalDate today() {
        return LocalDate.now(userZone);
    }

    /**
     * The current moment expressed in the user zone (same instant as UTC).
     */
    public OffsetDateTime now() {
        return OffsetDateTime.now(userZone);
    }
}
