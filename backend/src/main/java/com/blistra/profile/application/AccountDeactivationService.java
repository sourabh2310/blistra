package com.blistra.profile.application;

import com.blistra.auth.google.GoogleIdTokenVerifier;
import com.blistra.auth.google.GoogleIdentity;
import com.blistra.common.exception.BadRequestException;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * "Delete account": deactivates the signed-in user's account without erasing
 * its data. The row becomes INACTIVE (it can no longer authenticate and every
 * session is revoked) and its email, phone, username and Google link are
 * released so the person can register again, by email/password or Google, as a
 * brand-new account. Finance history shared with friends stays intact under
 * the anonymised "Deleted user" identity, and shared trip groups pass to
 * another accepted member.
 */
@Slf4j
@Service
public class AccountDeactivationService {

    static final String DELETED_DISPLAY_NAME = "Deleted user";

    private final CurrentUserProvider currentUserProvider;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final GoogleIdTokenVerifier googleVerifier;
    private final JdbcTemplate jdbc;

    public AccountDeactivationService(CurrentUserProvider currentUserProvider,
                                      UserRepository userRepository,
                                      PasswordEncoder passwordEncoder,
                                      GoogleIdTokenVerifier googleVerifier,
                                      JdbcTemplate jdbc) {
        this.currentUserProvider = currentUserProvider;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.googleVerifier = googleVerifier;
        this.jdbc = jdbc;
    }

    /**
     * Re-authenticates with the current password or, for accounts linked to
     * Google, a fresh Google ID token, then deactivates the account.
     */
    @Transactional
    public void deactivateCurrentAccount(String currentPassword, String googleIdToken) {
        User user = currentUserProvider.getCurrentUser();
        confirmIdentity(user, currentPassword, googleIdToken);
        UUID id = user.getId();

        String tag = id.toString().replace("-", "").substring(0, 12);
        user.setUsername("deleted_" + tag);
        user.setEmail("deleted+" + id + "@deleted.blistra.invalid");
        user.setPhone(null);
        user.setPendingEmail(null);
        user.setPendingPhone(null);
        user.setGoogleSub(null);
        user.setEmailVerified(false);
        user.setPhoneVerified(false);
        // Unusable hash: nothing can ever match it.
        user.setPasswordHash("!deleted!" + UUID.randomUUID());
        user.setStatus(UserStatus.INACTIVE);
        user.revokeSessions();
        userRepository.save(user);

        // Shared trip groups must not be stranded with an inactive owner: hand
        // them to the longest-standing accepted member. Groups nobody else has
        // joined stay as they are.
        jdbc.update("""
                UPDATE finance_groups g SET owner_id = (
                    SELECT m.user_id FROM finance_group_members m
                    WHERE m.group_id = g.id AND m.user_id <> ? AND m.status = 'ACCEPTED'
                    ORDER BY m.joined_at, m.user_id LIMIT 1)
                WHERE g.owner_id = ? AND EXISTS (
                    SELECT 1 FROM finance_group_members m
                    WHERE m.group_id = g.id AND m.user_id <> ? AND m.status = 'ACCEPTED')
                """, id, id, id);

        // Stop codes and push notifications reaching a deactivated account, and
        // hide the name from friends who still see shared expenses.
        jdbc.update("DELETE FROM verification_otps WHERE user_id = ?", id);
        jdbc.update("DELETE FROM device_registrations WHERE user_id = ?", id);
        jdbc.update("UPDATE user_profiles SET display_name = ? WHERE user_id = ?",
                DELETED_DISPLAY_NAME, id);

        log.info("Account {} deactivated", id);
    }

    /**
     * Failed re-authentication answers 400, not 401: clients treat 401 as an
     * expired session and sign the user out, which a mistyped password must not do.
     */
    private void confirmIdentity(User user, String currentPassword, String googleIdToken) {
        if (googleIdToken != null && !googleIdToken.isBlank()) {
            GoogleIdentity identity = googleVerifier.verify(googleIdToken);
            if (user.getGoogleSub() == null
                    || !user.getGoogleSub().equals(identity.subject())) {
                throw new BadRequestException("That Google account does not match this account.");
            }
            return;
        }
        if (currentPassword == null
                || !passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new BadRequestException("Current password is incorrect");
        }
    }
}
