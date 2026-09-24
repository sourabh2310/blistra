package com.blistra.auth.application;

import com.blistra.auth.dto.AuthResponse;
import com.blistra.auth.dto.AvailabilityResponse;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RecoveryChannelsResponse;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.auth.dto.UserResponse;
import com.blistra.auth.identity.IdentifierType;
import com.blistra.auth.identity.IdentityNormalizer;
import com.blistra.auth.otp.OtpChannel;
import com.blistra.auth.otp.OtpProperties;
import com.blistra.auth.otp.OtpPurpose;
import com.blistra.auth.otp.VerificationOtp;
import com.blistra.auth.otp.VerificationService;
import com.blistra.auth.security.JwtProvider;
import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.common.exception.OtpVerificationException;
import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.common.exception.VerificationUnavailableException;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserProfile;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserProfileRepository;
import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserProfileRepository userProfileRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtProvider jwtProvider;

    @Autowired
    private VerificationService verificationService;

    @Autowired
    private OtpProperties otpProperties;

    @Value("${JWT_EXPIRATION:${jwt.expiration:86400000}}")
    private long jwtExpirationMs;

    @Transactional(readOnly = true)
    public AvailabilityResponse checkAvailability(String username, String email, String phone) {
        Boolean usernameAvailable = null;
        if (username != null && !username.isBlank()) {
            String normalized = IdentityNormalizer.normalizeUsername(username);
            usernameAvailable = normalized != null
                    && IdentityNormalizer.isValidUsername(normalized)
                    && !userRepository.existsByUsernameIgnoreCase(normalized);
        }
        Boolean emailAvailable = null;
        if (email != null && !email.isBlank()) {
            String normalized = IdentityNormalizer.normalizeEmail(email);
            emailAvailable = normalized != null
                    && IdentityNormalizer.isValidEmail(email)
                    && !userRepository.existsByEmailIgnoreCase(normalized);
        }
        Boolean phoneAvailable = null;
        if (phone != null && !phone.isBlank()) {
            String normalized = IdentityNormalizer.normalizePhone(phone);
            phoneAvailable = normalized != null
                    && IdentityNormalizer.isValidPhone(phone)
                    && !userRepository.existsByPhone(normalized);
        }
        return AvailabilityResponse.builder()
                .usernameAvailable(usernameAvailable)
                .emailAvailable(emailAvailable)
                .phoneAvailable(phoneAvailable)
                .build();
    }

    @Transactional
    public UserResponse register(RegisterRequest request) {
        log.debug("Attempting to register user");

        String email = IdentityNormalizer.normalizeEmail(request.getEmail());
        if (!IdentityNormalizer.isValidEmail(request.getEmail())) {
            throw new BadRequestException("Email must be a valid email address.");
        }
        if (userRepository.existsByEmailIgnoreCase(email)) {
            log.warn("Registration attempt for existing email");
            throw new ResourceAlreadyExistsException("Email already registered");
        }

        boolean explicitUsername = request.getUsername() != null
                && !request.getUsername().isBlank();
        String username = IdentityNormalizer.normalizeUsername(request.getUsername());
        if (username == null) {
            // Legacy clients: derive from email and de-duplicate automatically.
            username = uniqueUsername(IdentityNormalizer.deriveUsername(email));
        } else {
            // Explicit usernames must match exactly; duplicates are rejected.
            if (!IdentityNormalizer.isValidUsername(username)) {
                throw new BadRequestException(
                        "Username must be 3-30 characters of letters, digits, underscore or dot.");
            }
            if (userRepository.existsByUsernameIgnoreCase(username)) {
                log.warn("Registration attempt for existing username");
                throw new ResourceAlreadyExistsException("Username already taken");
            }
        }
        if (!explicitUsername && !IdentityNormalizer.isValidUsername(username)) {
            throw new BadRequestException(
                    "Username must be 3-30 characters of letters, digits, underscore or dot.");
        }

        String phone = null;
        if (request.getPhone() != null && !request.getPhone().isBlank()) {
            if (!IdentityNormalizer.isValidPhone(request.getPhone())) {
                throw new BadRequestException(
                        "Phone must be in international format, e.g. +919876543210.");
            }
            phone = IdentityNormalizer.normalizePhone(request.getPhone());
            if (userRepository.existsByPhone(phone)) {
                log.warn("Registration attempt for existing phone");
                throw new ResourceAlreadyExistsException("Phone number already registered");
            }
        }

        User user = new User(email, passwordEncoder.encode(request.getPassword()));
        user.setUsername(username);
        user.setPhone(phone);
        user.setStatus(UserStatus.PENDING_VERIFICATION);
        if (Boolean.TRUE.equals(request.getTermsAccepted())) {
            user.setTermsAcceptedAt(LocalDateTime.now());
        }
        User saved = userRepository.save(user);

        UserProfile profile = new UserProfile(saved.getId());
        String displayName = request.getDisplayName();
        profile.setDisplayName(displayName != null && !displayName.isBlank()
                ? displayName.trim()
                : displayFromEmail(email));
        userProfileRepository.save(profile);

        log.info("User registered: {}", saved.getId());

        // Verification codes are part of onboarding, but delivery must never
        // roll the account back: a misconfigured sender surfaces on resend.
        try {
            verificationService.issue(saved.getId(), OtpPurpose.EMAIL_VERIFY,
                    OtpChannel.EMAIL, email);
            if (phone != null) {
                verificationService.issue(saved.getId(), OtpPurpose.PHONE_VERIFY,
                        OtpChannel.SMS, phone);
            }
        } catch (VerificationUnavailableException e) {
            log.error("Verification sender unavailable after registration for {}", saved.getId());
        }

        String token = jwtProvider.generateToken(saved.getId(), saved.getEmail());
        return mapToUserResponse(saved, token);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        log.debug("Attempting login");

        String identifier = request.effectiveIdentifier();
        User user = resolveUser(identifier)
                .orElseThrow(() -> {
                    log.warn("Login attempt for unknown account");
                    return new InvalidCredentialsException("Invalid email or password");
                });

        // Blocked accounts are rejected with the same generic message to avoid
        // account enumeration. PENDING_VERIFICATION may sign in to verify and
        // complete onboarding; the client routes on the returned flags.
        if (user.isBlocked()) {
            log.warn("Login attempt for blocked account: {}", user.getId());
            throw new InvalidCredentialsException("Invalid email or password");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            log.warn("Failed login attempt for user: {}", user.getId());
            throw new InvalidCredentialsException("Invalid email or password");
        }

        String token = jwtProvider.generateToken(user.getId(), user.getEmail());
        log.info("User logged in successfully: {}", user.getId());

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .expiresIn(jwtExpirationMs / 1000)
                .user(mapToUserResponse(user, null))
                .build();
    }

    @Transactional
    public UserResponse verifyEmail(UUID userId, String code) {
        User user = requireUser(userId);
        VerificationOtp otp = verificationService.verify(userId, OtpPurpose.EMAIL_VERIFY, code);
        if (!otp.getDestination().equalsIgnoreCase(user.getEmail())
                && (user.getPendingEmail() == null
                        || !otp.getDestination().equalsIgnoreCase(user.getPendingEmail()))) {
            throw new OtpVerificationException("INVALID_OTP", "Invalid or expired code.");
        }
        user.setEmailVerified(true);
        maybeActivate(user);
        userRepository.save(user);
        return mapToUserResponse(user, null);
    }

    @Transactional
    public UserResponse verifyPhone(UUID userId, String code) {
        User user = requireUser(userId);
        if (user.getPhone() == null) {
            throw new BadRequestException("No phone number on this account.");
        }
        VerificationOtp otp = verificationService.verify(userId, OtpPurpose.PHONE_VERIFY, code);
        if (!otp.getDestination().equals(user.getPhone())
                && (user.getPendingPhone() == null
                        || !otp.getDestination().equals(user.getPendingPhone()))) {
            throw new OtpVerificationException("INVALID_OTP", "Invalid or expired code.");
        }
        user.setPhoneVerified(true);
        maybeActivate(user);
        userRepository.save(user);
        return mapToUserResponse(user, null);
    }

    @Transactional
    public VerificationService.Issuance resendEmail(UUID userId) {
        User user = requireUser(userId);
        return verificationService.issue(userId, OtpPurpose.EMAIL_VERIFY,
                OtpChannel.EMAIL, user.getEmail());
    }

    @Transactional
    public VerificationService.Issuance resendPhone(UUID userId) {
        User user = requireUser(userId);
        if (user.getPhone() == null) {
            throw new BadRequestException("No phone number on this account.");
        }
        return verificationService.issue(userId, OtpPurpose.PHONE_VERIFY,
                OtpChannel.SMS, user.getPhone());
    }

    /**
     * Resolves an identifier to its verified recovery channels. Unknown,
     * blank or blocked identifiers yield 404 so the client stops before any
     * OTP is generated or sent. Only verified destinations are offered, and
     * only in masked form.
     */
    @Transactional(readOnly = true)
    public RecoveryChannelsResponse recoveryChannels(String identifier) {
        User user = resolveUser(identifier)
                .filter(u -> !u.isBlocked())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Couldn't find an account with those details."));
        List<String> channels = new java.util.ArrayList<>();
        String emailMasked = null;
        String phoneMasked = null;
        if (user.isEmailVerified()) {
            channels.add("EMAIL");
            emailMasked = maskEmail(user.getEmail());
        }
        if (user.getPhone() != null && user.isPhoneVerified()) {
            channels.add("SMS");
            phoneMasked = maskPhone(user.getPhone());
        }
        return RecoveryChannelsResponse.builder()
                .channels(channels)
                .emailMasked(emailMasked)
                .phoneMasked(phoneMasked)
                .build();
    }

    /**
     * Always succeeds with a generic message so callers cannot probe for
     * account existence. Rate limits apply silently. An OTP is issued only
     * to a verified destination: unknown/blocked accounts and unverified
     * channels produce no OTP at all.
     */
    @Transactional
    public void forgotPassword(String identifier, String channel) {
        Optional<User> maybe = resolveUser(identifier);
        if (maybe.isEmpty()) {
            log.debug("Password recovery for unknown identifier");
            return;
        }
        User user = maybe.get();
        if (user.isBlocked()) {
            log.debug("Password recovery for blocked account");
            return;
        }
        Optional<OtpChannel> chosen = chooseVerifiedRecoveryChannel(user, channel);
        if (chosen.isEmpty()) {
            log.debug("Password recovery with no verified channel for user {}", user.getId());
            return;
        }
        OtpChannel target = chosen.get();
        String destination = target == OtpChannel.EMAIL ? user.getEmail() : user.getPhone();
        if (destination == null) {
            return;
        }
        try {
            verificationService.issue(user.getId(), OtpPurpose.PASSWORD_RESET, target, destination);
        } catch (VerificationUnavailableException | com.blistra.common.exception.TooManyRequestsException
                | com.blistra.common.exception.ResendCooldownException e) {
            log.debug("Recovery OTP throttled/unavailable for user {}", user.getId());
        }
    }

    @Transactional
    public void resetPassword(String identifier, String code, String newPassword, String confirmPassword) {
        if (!newPassword.equals(confirmPassword)) {
            throw new BadRequestException("Passwords do not match.");
        }
        User user = resolveUser(identifier).orElseThrow(() ->
                new OtpVerificationException("INVALID_OTP", "Invalid or expired code."));
        if (user.isBlocked()) {
            throw new OtpVerificationException("INVALID_OTP", "Invalid or expired code.");
        }
        verificationService.verify(user.getId(), OtpPurpose.PASSWORD_RESET, code);
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        maybeActivate(user);
        userRepository.save(user);
        log.info("Password reset for user {}", user.getId());
    }

    @Transactional
    public UserResponse changePassword(UUID userId, String currentPassword, String newPassword) {
        User user = requireUser(userId);
        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new InvalidCredentialsException("Invalid email or password");
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        return mapToUserResponse(user, null);
    }

    /** Dev-only: latest usable code for the account (403/404 outside dev mode). */
    @Transactional(readOnly = true)
    public Optional<VerificationOtp> devLatestCode(UUID userId, OtpPurpose purpose) {
        if (!otpProperties.isDevMode()) {
            return Optional.empty();
        }
        return verificationService.latestActive(userId, purpose);
    }

    public boolean isDevMode() {
        return otpProperties.isDevMode();
    }

    private Optional<User> resolveUser(String identifier) {
        if (identifier == null || identifier.isBlank()) {
            return Optional.empty();
        }
        String value = identifier.trim();
        IdentifierType type = IdentityNormalizer.classify(value);
        return switch (type) {
            case EMAIL -> {
                String email = IdentityNormalizer.normalizeEmail(value);
                yield email == null
                        ? Optional.empty()
                        : userRepository.findByEmailIgnoreCase(email);
            }
            case PHONE -> {
                String phone = IdentityNormalizer.normalizePhone(value);
                yield !IdentityNormalizer.isValidPhone(value)
                        ? Optional.empty()
                        : userRepository.findByPhone(phone);
            }
            case USERNAME -> {
                String username = IdentityNormalizer.normalizeUsername(value);
                yield username == null
                        ? Optional.empty()
                        : userRepository.findByUsernameIgnoreCase(username);
            }
        };
    }

    /**
     * Verified-only recovery channel selection. An explicitly requested
     * channel is honoured only when verified; an unspecified request prefers
     * the verified email, then the verified phone. Empty when nothing the
     * caller may use is verified — the caller must not send an OTP then.
     */
    private Optional<OtpChannel> chooseVerifiedRecoveryChannel(User user, String requested) {
        if ("SMS".equalsIgnoreCase(requested) || "PHONE".equalsIgnoreCase(requested)) {
            return user.getPhone() != null && user.isPhoneVerified()
                    ? Optional.of(OtpChannel.SMS)
                    : Optional.empty();
        }
        if ("EMAIL".equalsIgnoreCase(requested)) {
            return user.isEmailVerified()
                    ? Optional.of(OtpChannel.EMAIL)
                    : Optional.empty();
        }
        if (user.isEmailVerified()) {
            return Optional.of(OtpChannel.EMAIL);
        }
        if (user.getPhone() != null && user.isPhoneVerified()) {
            return Optional.of(OtpChannel.SMS);
        }
        return Optional.empty();
    }

    private static String maskEmail(String email) {
        if (email == null || !email.contains("@")) {
            return "***";
        }
        String local = email.substring(0, email.indexOf('@'));
        String domain = email.substring(email.indexOf('@') + 1);
        String shown = local.length() <= 2 ? local + "***" : local.substring(0, 2) + "***";
        return shown + "@" + domain;
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 2) {
            return "***";
        }
        return "***" + phone.substring(phone.length() - 2);
    }

    private User requireUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));
    }

    private void maybeActivate(User user) {
        if (user.isEmailVerified()
                && (user.getPhone() == null || user.isPhoneVerified())
                && user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            user.setStatus(UserStatus.ACTIVE);
        }
    }

    private String uniqueUsername(String base) {
        String candidate = base;
        int suffix = 1;
        while (userRepository.existsByUsernameIgnoreCase(candidate)) {
            suffix++;
            String tail = "_" + suffix;
            candidate = base.length() + tail.length() > 30
                    ? base.substring(0, 30 - tail.length()) + tail
                    : base + tail;
        }
        return candidate;
    }

    private static String displayFromEmail(String email) {
        String local = email.contains("@") ? email.substring(0, email.indexOf('@')) : email;
        String cleaned = local.replaceAll("[._\\-+]+", " ").trim();
        if (cleaned.isEmpty()) {
            return "there";
        }
        String[] parts = cleaned.split("\\s+");
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (p.isEmpty()) {
                continue;
            }
            if (sb.length() > 0) {
                sb.append(' ');
            }
            sb.append(Character.toUpperCase(p.charAt(0)));
            if (p.length() > 1) {
                sb.append(p.substring(1));
            }
        }
        return sb.toString();
    }

    private UserResponse mapToUserResponse(User user, String token) {
        return UserResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .phone(user.getPhone())
                .emailVerified(user.isEmailVerified())
                .phoneVerified(user.isPhoneVerified())
                .onboardingCompleted(user.isOnboardingCompleted())
                .status(user.getStatus().toString())
                .token(token)
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    }
}
