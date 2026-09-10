package com.blistra.auth.security;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Authenticated principal carrying the owning user's id in addition to the
 * username (email). This allows domain modules to derive resource ownership from
 * the trusted security context without an additional per-request lookup.
 */
public class BlistraUserPrincipal implements UserDetails {

    private final UUID id;
    private final String email;
    private final String passwordHash;
    private final Collection<? extends GrantedAuthority> authorities;

    public BlistraUserPrincipal(UUID id, String email, String passwordHash,
                                Collection<? extends GrantedAuthority> authorities) {
        this.id = id;
        this.email = email;
        this.passwordHash = passwordHash;
        this.authorities = authorities == null ? List.of() : List.copyOf(authorities);
    }

    public UUID getId() {
        return id;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}