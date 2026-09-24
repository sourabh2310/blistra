package com.blistra.auth.identity;

import java.util.regex.Pattern;

/**
 * Single authority for username/email/phone normalization, validation and
 * login-identifier classification. Normalization is enforced server-side;
 * client checks are convenience only.
 */
public final class IdentityNormalizer {

    private IdentityNormalizer() {
    }

    private static final Pattern USERNAME_PATTERN = Pattern.compile("^[A-Za-z0-9_.]{3,30}$");
    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    /** Canonical E.164: leading +, country code, 7-15 digits total. */
    private static final Pattern PHONE_PATTERN = Pattern.compile("^\\+[1-9][0-9]{6,14}$");
    /** Digits that may represent a phone number (login classification). */
    private static final Pattern PHONE_LIKE_PATTERN = Pattern.compile("^\\+?[0-9][0-9\\s\\-()]{5,18}$");

    /** Lowercase-trimmed username, or null when blank. */
    public static String normalizeUsername(String username) {
        if (username == null) {
            return null;
        }
        String value = username.trim().toLowerCase();
        return value.isEmpty() ? null : value;
    }

    /** True when the normalized username matches the account rules. */
    public static boolean isValidUsername(String username) {
        String value = normalizeUsername(username);
        return value != null && USERNAME_PATTERN.matcher(value).matches();
    }

    /** Lowercase-trimmed email, or null when blank. */
    public static String normalizeEmail(String email) {
        if (email == null) {
            return null;
        }
        String value = email.trim().toLowerCase();
        return value.isEmpty() ? null : value;
    }

    public static boolean isValidEmail(String email) {
        String value = normalizeEmail(email);
        return value != null && EMAIL_PATTERN.matcher(value).matches();
    }

    /**
     * Canonical E.164 phone, or null when blank. Strips spaces, dashes,
     * dots and parentheses. A missing leading + is rejected: the caller must
     * supply the country code (no regional assumption is made).
     */
    public static String normalizePhone(String phone) {
        if (phone == null) {
            return null;
        }
        String value = phone.trim().replaceAll("[\\s\\-().]", "");
        if (value.isEmpty()) {
            return null;
        }
        return value;
    }

    public static boolean isValidPhone(String phone) {
        String value = normalizePhone(phone);
        return value != null && PHONE_PATTERN.matcher(value).matches();
    }

    /**
     * Classifies a login identifier: email when it contains @, phone when it
     * looks like an international number, username otherwise. The same account
     * is reachable through all three.
     */
    public static IdentifierType classify(String identifier) {
        String value = identifier == null ? "" : identifier.trim();
        if (value.contains("@")) {
            return IdentifierType.EMAIL;
        }
        if (PHONE_LIKE_PATTERN.matcher(value).matches()) {
            return IdentifierType.PHONE;
        }
        return IdentifierType.USERNAME;
    }

    /**
     * Derives a fallback username from an email local part for legacy
     * compatibility (API clients that predate the username field). The result
     * still passes through {@link #isValidUsername} + uniqueness checks.
     */
    public static String deriveUsername(String email) {
        String normalized = normalizeEmail(email);
        String local = normalized != null && normalized.contains("@")
                ? normalized.substring(0, normalized.indexOf('@'))
                : "user";
        String cleaned = local.replaceAll("[^a-z0-9_.]", "");
        if (cleaned.length() < 3) {
            cleaned = ("user_" + Math.abs((email == null ? "x" : email).hashCode()));
        }
        if (cleaned.length() > 30) {
            cleaned = cleaned.substring(0, 30);
        }
        return cleaned;
    }
}
