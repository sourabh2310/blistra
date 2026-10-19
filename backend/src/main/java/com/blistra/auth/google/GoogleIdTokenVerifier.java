package com.blistra.auth.google;

/** Verifies a Google ID token issued to one of this app's OAuth client ids. */
public interface GoogleIdTokenVerifier {

    boolean isConfigured();

    /**
     * @throws com.blistra.common.exception.InvalidCredentialsException when the
     *         token is malformed, expired, or not issued by Google for this app
     */
    GoogleIdentity verify(String idToken);
}
