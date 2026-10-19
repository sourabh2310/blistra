package com.blistra.auth.google;

import com.blistra.common.exception.InvalidCredentialsException;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NimbusGoogleIdTokenVerifierTest {

    private static Jwt jwt(String issuer, List<String> audience) {
        return Jwt.withTokenValue("t")
                .header("alg", "RS256")
                .claim("iss", issuer)
                .claim("aud", audience)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(600))
                .build();
    }

    @Test
    void acceptsBothGoogleIssuerForms() {
        var validator = NimbusGoogleIdTokenVerifier.issuerValidator();
        assertThat(validator.validate(jwt("https://accounts.google.com", List.of("a"))).hasErrors())
                .isFalse();
        assertThat(validator.validate(jwt("accounts.google.com", List.of("a"))).hasErrors())
                .isFalse();
    }

    @Test
    void rejectsOtherIssuers() {
        var validator = NimbusGoogleIdTokenVerifier.issuerValidator();
        assertThat(validator.validate(jwt("https://evil.example.com", List.of("a"))).hasErrors())
                .isTrue();
    }

    @Test
    void audienceMustMatchAConfiguredClientId() {
        var validator = NimbusGoogleIdTokenVerifier.audienceValidator(Set.of("mine", "other"));
        assertThat(validator.validate(jwt("accounts.google.com", List.of("mine"))).hasErrors())
                .isFalse();
        assertThat(validator.validate(jwt("accounts.google.com", List.of("stranger"))).hasErrors())
                .isTrue();
    }

    @Test
    void isUnconfiguredWithoutClientIdsAndRefusesToVerify() {
        var verifier = new NimbusGoogleIdTokenVerifier(" , ");

        assertThat(verifier.isConfigured()).isFalse();
        assertThatThrownBy(() -> verifier.verify("anything"))
                .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    void parsesCommaSeparatedClientIds() {
        assertThat(new NimbusGoogleIdTokenVerifier("a.apps.googleusercontent.com, b").isConfigured())
                .isTrue();
    }

    @Test
    void rejectsGarbageTokensWithoutCallingGoogle() {
        var verifier = new NimbusGoogleIdTokenVerifier("client");

        assertThatThrownBy(() -> verifier.verify("not-a-jwt"))
                .isInstanceOf(InvalidCredentialsException.class);
    }
}
