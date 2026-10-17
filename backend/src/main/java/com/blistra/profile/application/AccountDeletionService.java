package com.blistra.profile.application;

import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.documents.storage.DocumentStorageService;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Permanently deletes the signed-in user's account and personal data.
 *
 * <p>Every per-user table cascades from {@code users} except finance, which
 * deliberately does not (see V100/V107). Personal finance rows are removed
 * explicitly. Expenses and settlements shared with friends belong to the
 * other people too, so when any remain the user row is anonymised and
 * deactivated instead of deleted: friends keep their history against a
 * "deleted user", and every personal record is still wiped.
 */
@Slf4j
@Service
public class AccountDeletionService {

    /**
     * Per-user tables wiped when the user row has to stay behind for shared
     * finance history. Children (meal items, doses, habit completions...)
     * cascade from these parents.
     */
    private static final List<String> USER_OWNED_TABLES = List.of(
            "documents", "diet_profiles", "meals", "water_intake",
            "health_profiles", "health_measurements", "health_sleep_records",
            "health_activities", "health_symptom_logs", "health_events",
            "health_appointments", "habits", "medicines",
            "notification_preferences", "reminders", "device_registrations",
            "planner_task", "planner_task_list", "planner_event",
            "verification_otps", "user_profiles", "user_app_preferences",
            "finance_budgets");

    private final CurrentUserProvider currentUserProvider;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbc;
    private final DocumentStorageService storage;

    public AccountDeletionService(CurrentUserProvider currentUserProvider,
                                  UserRepository userRepository,
                                  PasswordEncoder passwordEncoder,
                                  JdbcTemplate jdbc,
                                  DocumentStorageService storage) {
        this.currentUserProvider = currentUserProvider;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jdbc = jdbc;
        this.storage = storage;
    }

    @Transactional
    public void deleteCurrentAccount(String currentPassword) {
        User user = currentUserProvider.getCurrentUser();
        if (currentPassword == null
                || !passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new InvalidCredentialsException("Current password is incorrect");
        }
        UUID id = user.getId();

        List<String> storedFiles = new ArrayList<>(jdbc.queryForList(
                "SELECT stored_object_key FROM documents WHERE user_id = ?", String.class, id));
        storedFiles.addAll(jdbc.queryForList(
                "SELECT avatar_object_key FROM user_profiles WHERE user_id = ? "
                        + "AND avatar_object_key IS NOT NULL", String.class, id));

        // Personal finance: ledger rows and expenses nobody else is part of.
        jdbc.update("DELETE FROM finance_transfers WHERE user_id = ?", id);
        jdbc.update("DELETE FROM finance_transactions WHERE user_id = ?", id);
        jdbc.update("DELETE FROM finance_categories WHERE user_id = ?", id);
        jdbc.update("DELETE FROM finance_accounts WHERE user_id = ?", id);
        jdbc.update("""
                DELETE FROM finance_expenses e
                WHERE e.created_by = ? AND e.paid_by = ?
                  AND NOT EXISTS (SELECT 1 FROM finance_expense_shares s
                                  WHERE s.expense_id = e.id AND s.user_id <> ?)
                """, id, id, id);

        Boolean shared = jdbc.queryForObject("""
                SELECT EXISTS (SELECT 1 FROM finance_expenses WHERE created_by = ? OR paid_by = ?)
                    OR EXISTS (SELECT 1 FROM finance_expense_shares WHERE user_id = ?)
                    OR EXISTS (SELECT 1 FROM finance_settlements
                               WHERE created_by = ? OR payer_id = ? OR payee_id = ?)
                """, Boolean.class, id, id, id, id, id, id);

        if (Boolean.TRUE.equals(shared)) {
            for (String table : USER_OWNED_TABLES) {
                jdbc.update("DELETE FROM " + table + " WHERE user_id = ?", id);
            }
            jdbc.update("DELETE FROM finance_friendships WHERE requester_id = ? OR addressee_id = ?",
                    id, id);
            anonymise(user);
            userRepository.save(user);
        } else {
            userRepository.delete(user);
        }

        deleteFilesAfterCommit(storedFiles);
        log.info("Account {} deleted ({})", id, Boolean.TRUE.equals(shared)
                ? "anonymised: shared finance history kept" : "removed");
    }

    private void anonymise(User user) {
        String tag = user.getId().toString().replace("-", "").substring(0, 12);
        user.setUsername("deleted_" + tag);
        user.setEmail("deleted+" + user.getId() + "@deleted.blistra.invalid");
        user.setPhone(null);
        user.setPendingEmail(null);
        user.setPendingPhone(null);
        user.setEmailVerified(false);
        user.setPhoneVerified(false);
        // Unusable hash: nothing can ever match it.
        user.setPasswordHash("!deleted!" + UUID.randomUUID());
        user.setStatus(UserStatus.INACTIVE);
    }

    private void deleteFilesAfterCommit(List<String> keys) {
        if (keys.isEmpty()) return;
        Runnable purge = () -> keys.forEach(key -> {
            try {
                storage.delete(key);
            } catch (RuntimeException e) {
                log.warn("Could not delete stored file {} for a deleted account", key, e);
            }
        });
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    purge.run();
                }
            });
        } else {
            purge.run();
        }
    }
}
