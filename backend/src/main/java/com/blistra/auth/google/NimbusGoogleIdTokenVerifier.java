package com.blistra.auth.google;

import com.blistra.common.exception.InvalidCredentialsException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Validates Google ID tokens against Google's published signing keys: RS256
 * signature, issuer, expiry, and that the audience is one of our client ids.
 */
@Slf4j
@Component
public class NimbusGoogleIdTokenVerifier implements GoogleIdTokenVerifier {

    private static final String JWKS_URI = "https://www.googleapis.com/oauth2/v3/certs";
    private static final Set<String> ISSUERS =
            Set.of("https://accounts.google.com", "accounts.google.com");

    private final Set<String> clientIds;
    private final NimbusJwtDecoder decoder;

    public NimbusGoogleIdTokenVerifier(
            @Value("${blistra.auth.google.client-ids:}") String clientIds) {
        this.clientIds = Arrays.stream(clientIds.split(","))
                .map(String::trim)
                .filter(id -> !id.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
        this.decoder = NimbusJwtDecoder.withJwkSetUri(JWKS_URI).build();
        this.decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                new JwtTimestampValidator(),
                issuerValidator(),
                audienceValidator(this.clientIds)));
    }

    @Override
    public boolean isConfigured() {
        return !clientIds.isEmpty();
    }

    @Override
    public GoogleIdentity verify(String idToken) {
        if (!isConfigured() || idToken == null || idToken.isBlank()) {
            throw new InvalidCredentialsException("Google sign-in failed");
        }
        try {
            Jwt jwt = decoder.decode(idToken.trim());
            return new GoogleIdentity(
                    jwt.getSubject(),
                    jwt.getClaimAsString("email"),
                    Boolean.TRUE.equals(jwt.getClaimAsBoolean("email_verified")),
                    jwt.getClaimAsString("name"));
        } catch (JwtException e) {
            log.warn("Rejected Google ID token: {}", e.getMessage());
            throw new InvalidCredentialsException("Google sign-in failed");
        }
    }

    static OAuth2TokenValidator<Jwt> issuerValidator() {
        return jwt -> {
            String issuer = jwt.getClaimAsString("iss");
            return issuer != null && ISSUERS.contains(issuer)
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(
                            new OAuth2Error("invalid_token", "Untrusted token issuer", null));
        };
    }

    static OAuth2TokenValidator<Jwt> audienceValidator(Set<String> allowed) {
        return jwt -> {
            boolean match = jwt.getAudience() != null
                    && jwt.getAudience().stream().anyMatch(allowed::contains);
            return match
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(
                            new OAuth2Error("invalid_token", "Token audience mismatch", null));
        };
    }
}
