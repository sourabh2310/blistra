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
    private String bio;
    private String gender;
    private String emergencyContactName;
    private String emergencyContactPhone;
    private String emergencyContactRelation;
    private boolean allowFriendRequests;
    private boolean hasAvatar;
    /** Signed in with / linked to Google; re-authenticates with Google. */
    private boolean googleLinked;
    /** Changes whenever the photo changes; clients use it as a cache key. */
    private Long avatarVersion;
    /** Staged email/phone waiting for OTP confirmation. */
    private String pendingEmail;
    private String pendingPhone;
    /** When the account was created. */
    private LocalDateTime memberSince;
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
