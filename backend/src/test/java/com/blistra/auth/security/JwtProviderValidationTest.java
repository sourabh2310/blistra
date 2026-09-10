package com.blistra.auth.security;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Regression tests for JWT secret configuration: the application must fail
 * fast when JWT_SECRET is missing or too short for HS256. No production
 * secret is hard-coded here; these values are test-only.
 */
class JwtProviderValidationTest {

    private JwtProvider providerWithSecret(String secret) {
        JwtProvider provider = new JwtProvider();
        ReflectionTestUtils.setField(provider, "jwtSecret", secret);
        return provider;
    }

    @Test
    void rejectsMissingSecret() {
        assertThatThrownBy(() -> providerWithSecret(null).validateSecret())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }

    @Test
    void rejectsBlankSecret() {
        assertThatThrownBy(() -> providerWithSecret("   ").validateSecret())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }

    @Test
    void rejectsShortSecret() {
        assertThatThrownBy(() -> providerWithSecret("too-short").validateSecret())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }

    @Test
    void acceptsAtLeast32Bytes() {
        providerWithSecret("0123456789abcdef0123456789abcdef").validateSecret();
    }
}
