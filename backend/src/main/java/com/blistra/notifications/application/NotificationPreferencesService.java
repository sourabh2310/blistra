package com.blistra.notifications.application;

import com.blistra.notifications.domain.NotificationPreferences;
import com.blistra.notifications.dto.NotificationPreferencesResponse;
import com.blistra.notifications.dto.NotificationPreferencesUpdateRequest;
import com.blistra.notifications.repository.NotificationPreferencesRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Notification preference service. Preferences are strictly user-scoped: they
 * are addressed by the authenticated user id, never by a client-supplied id.
 */
@Service
@Transactional
public class NotificationPreferencesService {

    private final NotificationPreferencesRepository preferencesRepository;
    private final CurrentUserProvider currentUserProvider;

    public NotificationPreferencesService(NotificationPreferencesRepository preferencesRepository,
                                          CurrentUserProvider currentUserProvider) {
        this.preferencesRepository = preferencesRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public NotificationPreferencesResponse getPreferences() {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOrCreate(user.getId()));
    }

    public NotificationPreferencesResponse update(NotificationPreferencesUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        NotificationPreferences preferences = getOrCreate(user.getId());

        if (request.getEnabled() != null) {
            preferences.setEnabled(request.getEnabled());
        }
        if (request.getMedicineEnabled() != null) {
            preferences.setMedicineEnabled(request.getMedicineEnabled());
        }
        if (request.getHabitEnabled() != null) {
            preferences.setHabitEnabled(request.getHabitEnabled());
        }
        if (request.getPlannerEnabled() != null) {
            preferences.setPlannerEnabled(request.getPlannerEnabled());
        }
        if (request.getHealthEnabled() != null) {
            preferences.setHealthEnabled(request.getHealthEnabled());
        }
        if (request.getGeneralEnabled() != null) {
            preferences.setGeneralEnabled(request.getGeneralEnabled());
        }
        if (request.getHideSensitiveContent() != null) {
            preferences.setHideSensitiveContent(request.getHideSensitiveContent());
        }

        return toResponse(preferencesRepository.save(preferences));
    }

    private NotificationPreferences getOrCreate(UUID userId) {
        return preferencesRepository.findById(userId)
                .orElseGet(() -> preferencesRepository.save(new NotificationPreferences(userId)));
    }

    private NotificationPreferencesResponse toResponse(NotificationPreferences preferences) {
        return NotificationPreferencesResponse.builder()
                .userId(preferences.getUserId())
                .enabled(preferences.isEnabled())
                .medicineEnabled(preferences.isMedicineEnabled())
                .habitEnabled(preferences.isHabitEnabled())
                .plannerEnabled(preferences.isPlannerEnabled())
                .healthEnabled(preferences.isHealthEnabled())
                .generalEnabled(preferences.isGeneralEnabled())
                .hideSensitiveContent(preferences.isHideSensitiveContent())
                .createdAt(preferences.getCreatedAt())
                .updatedAt(preferences.getUpdatedAt())
                .build();
    }
}