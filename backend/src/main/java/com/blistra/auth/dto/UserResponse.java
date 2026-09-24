package com.blistra.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserResponse {
    private UUID id;
    private String username;
    private String email;
    private String phone;
    private boolean emailVerified;
    private boolean phoneVerified;
    private boolean onboardingCompleted;
    private String status;
    /** Present only on registration (lets the client verify without a second login). */
    private String token;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
