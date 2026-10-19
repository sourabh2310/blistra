package com.blistra.auth.google;

/** Verified claims from a Google ID token. */
public record GoogleIdentity(String subject, String email, boolean emailVerified, String name) {
}
