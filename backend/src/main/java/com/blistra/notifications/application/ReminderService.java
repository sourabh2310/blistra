package com.blistra.notifications.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.notifications.domain.Reminder;
import com.blistra.notifications.domain.ReminderStatus;
import com.blistra.notifications.domain.ReminderType;
import com.blistra.notifications.dto.ReminderRequest;
import com.blistra.notifications.dto.ReminderResponse;
import com.blistra.notifications.dto.ReminderUpdateRequest;
import com.blistra.notifications.exception.InvalidReminderTimeException;
import com.blistra.notifications.exception.ReminderStateConflictException;
import com.blistra.notifications.repository.ReminderRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

/**
 * Reminder application service. Ownership is always derived from the
 * authenticated security context; no user id is ever accepted from the client.
 */
@Service
@Transactional
public class ReminderService {

    private final ReminderRepository reminderRepository;
    private final CurrentUserProvider currentUserProvider;

    public ReminderService(ReminderRepository reminderRepository,
                           CurrentUserProvider currentUserProvider) {
        this.reminderRepository = reminderRepository;
        this.currentUserProvider = currentUserProvider;
    }

    public ReminderResponse create(ReminderRequest request) {
        User user = currentUserProvider.getCurrentUser();

        // The owning domains create MEDICINE/HABIT/PLANNER/HEALTH reminders
        // through their own (future) read-only integration. The client can only
        // create standalone GENERAL reminders, which are owned by this module.
        if (request.getType() != ReminderType.GENERAL) {
            throw new BadRequestException(
                    "Domain-generated reminders are created by their owning module");
        }
        if (request.getSourceId() != null) {
            throw new BadRequestException("Source reference is managed by the owning module");
        }

        validateFuture(request.getScheduledAt());
        String timezone = normalizeTimezone(request.getTimezone());

        Reminder reminder = new Reminder();
        reminder.setUser(user);
        reminder.setType(request.getType());
        reminder.setTitle(request.getTitle().trim());
        reminder.setBody(normalizeBody(request.getBody()));
        reminder.setScheduledAt(request.getScheduledAt());
        reminder.setTimezone(timezone);
        reminder.setStatus(ReminderStatus.SCHEDULED);

        return toResponse(reminderRepository.save(reminder));
    }

    @Transactional(readOnly = true)
    public List<ReminderResponse> list(String status) {
        User user = currentUserProvider.getCurrentUser();
        List<Reminder> reminders;
        if (status == null || status.equalsIgnoreCase("SCHEDULED")) {
            reminders = reminderRepository.findByUserIdAndStatusOrderByScheduledAtAsc(
                    user.getId(), ReminderStatus.SCHEDULED);
        } else if (status.equalsIgnoreCase("CANCELLED")) {
            reminders = reminderRepository.findByUserIdAndStatusOrderByScheduledAtAsc(
                    user.getId(), ReminderStatus.CANCELLED);
        } else if (status.equalsIgnoreCase("ALL")) {
            reminders = reminderRepository.findByUserIdOrderByScheduledAtAsc(user.getId());
        } else {
            throw new BadRequestException("Invalid reminder status filter");
        }
        return reminders.stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public ReminderResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(findOwned(id, user.getId()));
    }

    public ReminderResponse update(UUID id, ReminderUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Reminder reminder = findOwned(id, user.getId());
        if (reminder.getStatus() == ReminderStatus.CANCELLED) {
            throw new ReminderStateConflictException("Cannot update a cancelled reminder");
        }

        boolean changed = false;
        if (request.getTitle() != null) {
            if (request.getTitle().isBlank()) {
                throw new BadRequestException("Title must not be blank");
            }
            reminder.setTitle(request.getTitle().trim());
            changed = true;
        }
        if (request.getBody() != null) {
            reminder.setBody(normalizeBody(request.getBody()));
            changed = true;
        }
        if (request.getScheduledAt() != null) {
            validateFuture(request.getScheduledAt());
            reminder.setScheduledAt(request.getScheduledAt());
            changed = true;
        }
        if (request.getTimezone() != null) {
            reminder.setTimezone(normalizeTimezone(request.getTimezone()));
            changed = true;
        }
        if (!changed) {
            throw new BadRequestException("No update fields provided");
        }
        return toResponse(reminderRepository.save(reminder));
    }

    /**
     * Cancels a reminder. Idempotent: cancelling an already-cancelled reminder
     * succeeds without error. Cancelled reminders are never treated as active.
     */
    public void reconcileTaskReminders(User user,
                                       UUID taskId,
                                       String title,
                                       String timezone,
                                       OffsetDateTime startAt,
                                       OffsetDateTime endAt,
                                       String mode) {
        cancelTaskReminders(user.getId(), taskId);
        if (mode == null || "NONE".equalsIgnoreCase(mode)) {
            return;
        }
        boolean start = "AT_START".equalsIgnoreCase(mode)
                || "AT_START_AND_END".equalsIgnoreCase(mode);
        boolean end = "AT_END".equalsIgnoreCase(mode)
                || "AT_START_AND_END".equalsIgnoreCase(mode);
        if (start && startAt != null && startAt.toInstant().isAfter(OffsetDateTime.now().toInstant())) {
            saveTaskReminder(user, taskId, title, timezone, startAt);
        }
        if (end && endAt != null && endAt.toInstant().isAfter(OffsetDateTime.now().toInstant())) {
            saveTaskReminder(user, taskId, title, timezone, endAt);
        }
    }

    public void cancelTaskReminders(UUID userId, UUID taskId) {
        for (Reminder reminder : reminderRepository
                .findByUserIdAndTypeAndSourceIdAndStatus(
                        userId, ReminderType.PLANNER, taskId, ReminderStatus.SCHEDULED)) {
            reminder.setStatus(ReminderStatus.CANCELLED);
            reminderRepository.save(reminder);
        }
    }

    private void saveTaskReminder(User user,
                                  UUID taskId,
                                  String title,
                                  String timezone,
                                  OffsetDateTime scheduledAt) {
        Reminder reminder = new Reminder();
        reminder.setUser(user);
        reminder.setType(ReminderType.PLANNER);
        reminder.setSourceId(taskId);
        reminder.setTitle(title);
        reminder.setBody("Task reminder");
        reminder.setScheduledAt(scheduledAt);
        reminder.setTimezone(timezone);
        reminder.setStatus(ReminderStatus.SCHEDULED);
        reminderRepository.save(reminder);
    }

    public void cancel(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        Reminder reminder = findOwned(id, user.getId());
        if (reminder.getStatus() == ReminderStatus.CANCELLED) {
            return;
        }
        reminder.setStatus(ReminderStatus.CANCELLED);
        reminderRepository.save(reminder);
    }

    private Reminder findOwned(UUID id, UUID userId) {
        return reminderRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Reminder not found"));
    }

    private void validateFuture(OffsetDateTime scheduledAt) {
        if (!scheduledAt.toInstant().isAfter(OffsetDateTime.now().toInstant())) {
            throw new InvalidReminderTimeException("Scheduled time must be in the future");
        }
    }

    private String normalizeTimezone(String timezone) {
        if (timezone == null || timezone.isBlank()) {
            throw new BadRequestException("Timezone is required");
        }
        try {
            return ZoneId.of(timezone.trim()).getId();
        } catch (Exception ex) {
            throw new BadRequestException("Invalid timezone");
        }
    }

    private String normalizeBody(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        return body.trim();
    }

    private ReminderResponse toResponse(Reminder reminder) {
        return ReminderResponse.builder()
                .id(reminder.getId())
                .type(reminder.getType())
                .title(reminder.getTitle())
                .body(reminder.getBody())
                .scheduledAt(reminder.getScheduledAt())
                .timezone(reminder.getTimezone())
                .status(reminder.getStatus())
                .sourceId(reminder.getSourceId())
                .createdAt(reminder.getCreatedAt())
                .updatedAt(reminder.getUpdatedAt())
                .build();
    }
}