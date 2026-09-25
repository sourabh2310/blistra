package com.blistra.profile.application;

import com.blistra.auth.identity.IdentityNormalizer;
import com.blistra.auth.otp.OtpChannel;
import com.blistra.auth.otp.OtpPurpose;
import com.blistra.auth.otp.VerificationService;
import com.blistra.auth.otp.VerificationOtp;
import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.profile.dto.ProfileRequest;
import com.blistra.profile.dto.ProfileResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserProfile;
import com.blistra.users.repository.UserProfileRepository;
import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Reads/updates the identity-adjacent profile and completes onboarding.
 * Sensitive identity changes (email/phone) are staged and require OTP;
 * the old verified value stays live until the new one verifies.
 */
@Slf4j
@Service
public class ProfileService {

    private final CurrentUserProvider currentUserProvider;
    private final UserRepository userRepository;
    private final UserProfileRepository profileRepository;
    private final PasswordEncoder passwordEncoder;
    private final VerificationService verificationService;

    public ProfileService(CurrentUserProvider currentUserProvider,
                          UserRepository userRepository,
                          UserProfileRepository profileRepository,
                          PasswordEncoder passwordEncoder,
                          VerificationService verificationService) {
        this.currentUserProvider = currentUserProvider;
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.passwordEncoder = passwordEncoder;
        this.verificationService = verificationService;
    }

    @Transactional(readOnly = true)
    public ProfileResponse get() {
        User user = currentUserProvider.getCurrentUser();
        UserProfile profile = profileFor(user.getId());
        return toResponse(user, profile);
    }

    @Transactional
    public ProfileResponse update(ProfileRequest request) {
        User user = currentUserProvider.getCurrentUser();
        UserProfile profile = profileFor(user.getId());
        if (request.getDisplayName() != null) {
            String name = request.getDisplayName().trim();
            profile.setDisplayName(name.isEmpty() ? null : name);
        }
        if (request.getDateOfBirth() != null) {
            profile.setDateOfBirth(request.getDateOfBirth());
        }
        if (request.getCountry() != null) {
            String country = request.getCountry().trim().toUpperCase(java.util.Locale.ROOT);
            if (!isIsoCountryCode(country)) {
                throw new BadRequestException("Country must be a valid ISO-3166 alpha-2 code");
            }
            profile.setCountry(country);
        }
        if (request.getTimezone() != null) {
            validateTimezone(request.getTimezone());
            profile.setTimezone(request.getTimezone());
        }
        if (request.getLanguage() != null) {
            profile.setLanguage(request.getLanguage());
        }
        if (request.getUnitSystem() != null) {
            profile.setUnitSystem(request.getUnitSystem());
        }
        profileRepository.save(profile);
        return toResponse(user, profile);
    }

    /**
     * Stages email/phone changes (OTP to the NEW destination) and applies
     * username changes immediately. Requires the current password.
     */
    @Transactional
    public ProfileResponse updateIdentity(String currentPassword, String username,
                                          String email, String phone) {
        User user = currentUserProvider.getCurrentUser();
        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new InvalidCredentialsException("Invalid email or password");
        }
        boolean usernameChanged = false;
        if (username != null && !username.isBlank()) {
            String normalized = IdentityNormalizer.normalizeUsername(username);
            if (!IdentityNormalizer.isValidUsername(username)) {
                throw new BadRequestException("Username must be 3-30 characters of letters, digits, underscore or dot.");
            }
            if (!normalized.equalsIgnoreCase(user.getUsername())
                    && userRepository.existsByUsernameIgnoreCase(normalized)) {
                throw new ResourceAlreadyExistsException("Username already taken");
            }
            user.setUsername(normalized);
            usernameChanged = true;
        }
        if (email != null && !email.isBlank()) {
            String normalized = IdentityNormalizer.normalizeEmail(email);
            if (!IdentityNormalizer.isValidEmail(email)) {
                throw new BadRequestException("Email must be a valid email address.");
            }
            if (!normalized.equalsIgnoreCase(user.getEmail())) {
                if (userRepository.existsByEmailIgnoreCase(normalized)) {
                    throw new ResourceAlreadyExistsException("Email already registered");
                }
                user.setPendingEmail(normalized);
                verificationService.issue(user.getId(), OtpPurpose.EMAIL_CHANGE,
                        OtpChannel.EMAIL, normalized);
            }
        }
        if (phone != null && !phone.isBlank()) {
            String normalized = IdentityNormalizer.normalizePhone(phone);
            if (!IdentityNormalizer.isValidPhone(phone)) {
                throw new BadRequestException("Phone must be in international format, e.g. +919876543210.");
            }
            if (!normalized.equals(user.getPhone())) {
                if (userRepository.existsByPhone(normalized)) {
                    throw new ResourceAlreadyExistsException("Phone number already registered");
                }
                user.setPendingPhone(normalized);
                verificationService.issue(user.getId(), OtpPurpose.PHONE_CHANGE,
                        OtpChannel.SMS, normalized);
            }
        }
        if (!usernameChanged && user.getPendingEmail() == null && user.getPendingPhone() == null
                && (username != null || email != null || phone != null)) {
            // Values identical to current: nothing to do, but not an error.
            log.debug("Identity update with unchanged values for user {}", user.getId());
        }
        userRepository.save(user);
        return toResponse(user, profileFor(user.getId()));
    }

    /**
     * Confirms one staged email/phone change with the OTP sent to the NEW
     * destination. The old value stays live until this succeeds.
     *
     * @param channel EMAIL confirms the pending email, SMS/PHONE the pending phone
     */
    @Transactional
    public ProfileResponse confirmIdentity(String code, String channel) {
        User user = currentUserProvider.getCurrentUser();
        boolean email = channel == null || channel.equalsIgnoreCase("EMAIL");
        if (email) {
            if (user.getPendingEmail() == null) {
                throw new BadRequestException("No pending email change to confirm.");
            }
            VerificationOtp otp = verificationService.verify(
                    user.getId(), OtpPurpose.EMAIL_CHANGE, code);
            if (!otp.getDestination().equalsIgnoreCase(user.getPendingEmail())) {
                throw new BadRequestException("Code does not match the pending email change.");
            }
            user.setEmail(user.getPendingEmail());
            user.setPendingEmail(null);
            user.setEmailVerified(true);
        } else {
            if (user.getPendingPhone() == null) {
                throw new BadRequestException("No pending phone change to confirm.");
            }
            VerificationOtp otp = verificationService.verify(
                    user.getId(), OtpPurpose.PHONE_CHANGE, code);
            if (!otp.getDestination().equals(user.getPendingPhone())) {
                throw new BadRequestException("Code does not match the pending phone change.");
            }
            user.setPhone(user.getPendingPhone());
            user.setPendingPhone(null);
            user.setPhoneVerified(true);
        }
        maybeActivate(user);
        userRepository.save(user);
        return toResponse(user, profileFor(user.getId()));
    }

    /** Marks onboarding complete once verification + required profile exist. */
    @Transactional
    public ProfileResponse completeOnboarding() {
        User user = currentUserProvider.getCurrentUser();
        List<String> missing = new ArrayList<>();
        if (!user.isEmailVerified()) {
            missing.add("email verification");
        }
        if (user.getPhone() != null && !user.isPhoneVerified()) {
            missing.add("phone verification");
        }
        UserProfile profile = profileFor(user.getId());
        if (profile.getDisplayName() == null || profile.getDisplayName().isBlank()) {
            missing.add("display name");
        }
        if (profile.getDateOfBirth() == null) {
            missing.add("date of birth");
        }
        if (profile.getCountry() == null) {
            missing.add("country");
        }
        if (profile.getTimezone() == null) {
            missing.add("timezone");
        }
        if (profile.getUnitSystem() == null || profile.getUnitSystem().isBlank()) {
            missing.add("unit system");
        }
        if (!missing.isEmpty()) {
            throw new BadRequestException(
                    "Onboarding incomplete. Missing: " + String.join(", ", missing) + ".");
        }
        user.setOnboardingCompleted(true);
        maybeActivate(user);
        userRepository.save(user);
        return toResponse(user, profile);
    }

    private void maybeActivate(User user) {
        if (user.isEmailVerified()
                && (user.getPhone() == null || user.isPhoneVerified())) {
            user.setStatus(com.blistra.users.domain.UserStatus.ACTIVE);
        }
    }

    private UserProfile profileFor(UUID userId) {
        return profileRepository.findByUserId(userId)
                .orElseGet(() -> profileRepository.save(new UserProfile(userId)));
    }

    private static boolean isIsoCountryCode(String country) {
        for (String isoCountry : java.util.Locale.getISOCountries()) {
            if (isoCountry.equals(country)) return true;
        }
        return false;
    }

    private static void validateTimezone(String timezone) {
        try {
            ZoneId.of(timezone);
        } catch (Exception e) {
            throw new BadRequestException("Unknown timezone: " + timezone);
        }
    }

    static ProfileResponse toResponse(User user, UserProfile profile) {
        return ProfileResponse.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .phone(user.getPhone())
                .emailVerified(user.isEmailVerified())
                .phoneVerified(user.isPhoneVerified())
                .onboardingCompleted(user.isOnboardingCompleted())
                .status(user.getStatus().toString())
                .displayName(profile.getDisplayName())
                .dateOfBirth(profile.getDateOfBirth())
                .age(ProfileResponse.ageOf(profile.getDateOfBirth()))
                .country(profile.getCountry())
                .timezone(profile.getTimezone())
                .language(profile.getLanguage())
                .unitSystem(profile.getUnitSystem())
                .createdAt(profile.getCreatedAt())
                .updatedAt(profile.getUpdatedAt())
                .build();
    }
}
