package com.blistra.profile.dto;

import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProfileRequest {

    @Size(max = 120, message = "Display name must be at most 120 characters")
    private String displayName;

    @Past(message = "Date of birth must be in the past")
    private LocalDate dateOfBirth;

    /** ISO-3166 alpha-2, e.g. IN, US. */
    @Pattern(regexp = "^[A-Z]{2}$", message = "Country must be a 2-letter ISO code")
    private String country;

    /** IANA timezone, e.g. Asia/Kolkata. */
    @Size(max = 64, message = "Timezone must be at most 64 characters")
    private String timezone;

    /** BCP-47-ish, e.g. en or en-IN. */
    @Pattern(regexp = "^[a-z]{2}(-[A-Z]{2})?$", message = "Language must look like en or en-IN")
    private String language;

    @Pattern(regexp = "^(METRIC|IMPERIAL)$", message = "Unit system must be METRIC or IMPERIAL")
    private String unitSystem;
}
