package com.blistra.notifications.repository;

import com.blistra.notifications.domain.Reminder;
import com.blistra.notifications.domain.ReminderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReminderRepository extends JpaRepository<Reminder, UUID> {

    Optional<Reminder> findByIdAndUserId(UUID id, UUID userId);

    List<Reminder> findByUserIdOrderByScheduledAtAsc(UUID userId);

    List<Reminder> findByUserIdAndStatusOrderByScheduledAtAsc(UUID userId, ReminderStatus status);

    /**
     * Source feed used by the scheduler: active reminders still in the future.
     */
    List<Reminder> findByUserIdAndStatusAndScheduledAtAfterOrderByScheduledAtAsc(
            UUID userId, ReminderStatus status, OffsetDateTime now);
}