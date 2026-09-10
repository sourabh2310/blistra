package com.blistra.diet.domain;

import java.util.Locale;

/**
 * Canonical water-intake units.
 *
 * <p>Legacy rows may contain {@code ml, mL, L, l, glass, glasses, cup, cups}.
 * All writes are normalized to the canonical set {@code ML, L, GLASS, CUP}
 * so aggregations never depend on spelling variants.</p>
 */
public enum WaterUnit {
    ML,
    L,
    GLASS,
    CUP;

    public static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        return switch (raw.trim().toLowerCase(Locale.ROOT)) {
            case "ml" -> ML.name();
            case "l" -> L.name();
            case "glass", "glasses" -> GLASS.name();
            case "cup", "cups" -> CUP.name();
            case "ML", "L", "GLASS", "CUP" -> raw.trim().toUpperCase(Locale.ROOT);
            default -> raw;
        };
    }

    public static boolean isCanonical(String raw) {
        if (raw == null) {
            return false;
        }
        for (WaterUnit u : values()) {
            if (u.name().equals(raw)) {
                return true;
            }
        }
        return false;
    }
}
