package com.blistra.auth.security;

import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    @Autowired
    private UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        if (user.isBlocked()) {
            throw new UsernameNotFoundException("User not found");
        }

        return new BlistraUserPrincipal(user.getId(), user.getEmail(), user.getPasswordHash(), java.util.List.of());
    }

    public UserDetails loadUserById(java.util.UUID id) throws UsernameNotFoundException {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        if (user.isBlocked()) {
            throw new UsernameNotFoundException("User not found");
        }

        return new BlistraUserPrincipal(user.getId(), user.getEmail(), user.getPasswordHash(), java.util.List.of());
    }

    /**
     * Resolves a token subject: new tokens carry the user id, legacy tokens
     * carry the email. Blocked (inactive/suspended) accounts authenticate as
     * absent in both cases.
     */
    public UserDetails loadBySubject(String subject) throws UsernameNotFoundException {
        try {
            return loadUserById(java.util.UUID.fromString(subject));
        } catch (IllegalArgumentException e) {
            return loadUserByUsername(subject);
        }
    }
}
