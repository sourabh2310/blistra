package com.blistra.auth.security;

import com.blistra.users.domain.User;
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
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        // User roles/authorities can be extended later. Carrying the id on the
        // principal lets domain modules derive resource ownership from the
        // trusted security context without additional lookups.
        return new BlistraUserPrincipal(user.getId(), user.getEmail(), user.getPasswordHash(), java.util.List.of());
    }
}
