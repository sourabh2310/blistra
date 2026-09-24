package com.blistra.profile.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Period;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ProfileResponse {
    private UUID userId;
    private String username;
    private String email;
    private String phone;
    private boolean emailVerified;
    private boolean phoneVerified;
    private boolean onboardingCompleted;
    private String status;
    private String displayName;
    private LocalDate dateOfBirth;
    /** Derived from dateOfBirth on every read; never stored. */
    private Integer age;
    private String country;
    private String timezone;
    private String language;
    private String unitSystem;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static Integer ageOf(LocalDate dateOfBirth) {
        if (dateOfBirth == null) {
            return null;
        }
        LocalDate today = LocalDate.now();
        if (dateOfBirth.isAfter(today)) {
            return null;
        }
        return Period.between(dateOfBirth, today).getYears();
    }
}
