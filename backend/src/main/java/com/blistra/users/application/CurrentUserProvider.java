package com.blistra.users.application;

import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

/**
 * Resolves the authenticated user from the trusted Spring Security context.
 *
 * The client never supplies the owning user id; it is always derived from the
 * authentication context. This is the basis of ownership enforcement in every
 * user-owned module.
 */
@Component
public class CurrentUserProvider {

    private final UserRepository userRepository;

    public CurrentUserProvider(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    /**
     * Returns the currently authenticated {@link User} or throws if the
     * security context contains no valid authenticated user.
     */
    public User getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()
                || !(authentication.getPrincipal() instanceof UserDetails userDetails)) {
            throw new InvalidCredentialsException("Authentication required");
        }
        // Prefer the stable principal id (survives email changes); fall back
        // to the email lookup for legacy tokens.
        User user;
        if (userDetails instanceof BlistraUserPrincipal principal) {
            user = userRepository.findById(principal.getId())
                    .orElseThrow(() -> new InvalidCredentialsException("Authentication required"));
        } else {
            user = userRepository.findByEmail(userDetails.getUsername())
                    .orElseThrow(() -> new InvalidCredentialsException("Authentication required"));
        }
        // PENDING_VERIFICATION accounts may use the app (verify, onboard and
        // manage their data); only blocked accounts are rejected here.
        if (user.isBlocked()) {
            throw new InvalidCredentialsException("Authentication required");
        }
        return user;
    }
}