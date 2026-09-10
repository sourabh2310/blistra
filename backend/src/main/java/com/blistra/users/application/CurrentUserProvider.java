package com.blistra.users.application;

import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
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
        String email = userDetails.getUsername();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new InvalidCredentialsException("Authentication required"));
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new InvalidCredentialsException("Authentication required");
        }
        return user;
    }
}