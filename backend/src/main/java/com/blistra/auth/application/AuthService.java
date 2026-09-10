package com.blistra.auth.application;

import com.blistra.auth.dto.AuthResponse;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.auth.dto.UserResponse;
import com.blistra.auth.security.JwtProvider;
import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtProvider jwtProvider;

    @Value("${JWT_EXPIRATION:86400000}")
    private long jwtExpirationMs;

    @Transactional
    public UserResponse register(RegisterRequest request) {
        log.debug("Attempting to register user");

        // Normalize email to lowercase for consistency
        String normalizedEmail = request.getEmail().toLowerCase().trim();

        // Check if user already exists
        if (userRepository.existsByEmail(normalizedEmail)) {
            log.warn("Registration attempt for existing account");
            throw new ResourceAlreadyExistsException("Email already registered");
        }

        // Encode password
        String encodedPassword = passwordEncoder.encode(request.getPassword());

        // Create and save user
        User user = new User(normalizedEmail, encodedPassword);
        User savedUser = userRepository.save(user);

        log.info("User registered successfully: {}", savedUser.getId());

        return mapToUserResponse(savedUser);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        log.debug("Attempting login");

        // Normalize email
        String normalizedEmail = request.getEmail().toLowerCase().trim();

        // Find user
        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> {
                    log.warn("Login attempt for unknown account");
                    return new InvalidCredentialsException("Invalid email or password");
                });

        // Only ACTIVE users may authenticate. INACTIVE and SUSPENDED users are
        // rejected with the same generic message to avoid account enumeration.
        if (user.getStatus() != UserStatus.ACTIVE) {
            log.warn("Login attempt for non-active account: {}", user.getId());
            throw new InvalidCredentialsException("Invalid email or password");
        }

        // Verify password
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            log.warn("Failed login attempt for user: {}", user.getId());
            throw new InvalidCredentialsException("Invalid email or password");
        }

        // Generate JWT token
        String token = jwtProvider.generateToken(
                new org.springframework.security.core.userdetails.User(
                        user.getEmail(),
                        user.getPasswordHash(),
                        new java.util.ArrayList<>()
                )
        );

        log.info("User logged in successfully: {}", user.getId());

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000) // Convert to seconds
                .user(mapToUserResponse(user))
                .build();
    }

    private UserResponse mapToUserResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .email(user.getEmail())
                .status(user.getStatus().toString())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    }
}
