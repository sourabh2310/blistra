package com.blistra.diet.application;

import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Resolves the authenticated user from the trusted security context.
 *
 * <p>Diet endpoints never accept a user id from the client; ownership is always
 * derived from the security context.</p>
 */
@Component
public class AuthenticatedUser {

    private final UserRepository userRepository;

    public AuthenticatedUser(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UUID getCurrentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalStateException("No authenticated user in security context");
        }
        Object principal = authentication.getPrincipal();
        if (principal instanceof BlistraUserPrincipal userPrincipal) {
            return userPrincipal.getId();
        }
        // Fallback for programmatically-settled principals that only carry the username.
        String email = authentication.getName();
        return userRepository.findByEmail(email)
                .map(User::getId)
                .orElseThrow(() -> new IllegalStateException("Authenticated user not found"));
    }
}