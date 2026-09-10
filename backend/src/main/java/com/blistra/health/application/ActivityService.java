package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthActivity;
import com.blistra.health.dto.ActivityRequest;
import com.blistra.health.dto.ActivityResponse;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.repository.HealthActivityRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
@Transactional
public class ActivityService {

    private final HealthActivityRepository activityRepository;
    private final CurrentUserProvider currentUserProvider;

    public ActivityService(HealthActivityRepository activityRepository,
                           CurrentUserProvider currentUserProvider) {
        this.activityRepository = activityRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<ActivityResponse> list(OffsetDateTime from, OffsetDateTime to, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<HealthActivity> page = activityRepository.search(user.getId(), from, to, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public ActivityResponse create(ActivityRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthActivity activity = new HealthActivity();
        activity.setUser(user);
        activity.setType(request.getType());
        activity.setPerformedAt(request.getPerformedAt());
        activity.setDurationMinutes(request.getDurationMinutes());
        activity.setDistanceKm(request.getDistanceKm());
        activity.setCaloriesBurned(request.getCaloriesBurned());
        activity.setNotes(request.getNotes());
        return toResponse(activityRepository.save(activity));
    }

    @Transactional(readOnly = true)
    public ActivityResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public ActivityResponse update(UUID id, ActivityRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthActivity activity = getOwned(id, user.getId());
        activity.setType(request.getType());
        activity.setPerformedAt(request.getPerformedAt());
        activity.setDurationMinutes(request.getDurationMinutes());
        activity.setDistanceKm(request.getDistanceKm());
        activity.setCaloriesBurned(request.getCaloriesBurned());
        activity.setNotes(request.getNotes());
        return toResponse(activityRepository.save(activity));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthActivity activity = getOwned(id, user.getId());
        activityRepository.delete(activity);
    }

    private HealthActivity getOwned(UUID id, UUID userId) {
        return activityRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Activity not found"));
    }

    private ActivityResponse toResponse(HealthActivity activity) {
        return ActivityResponse.builder()
                .id(activity.getId())
                .type(activity.getType())
                .performedAt(activity.getPerformedAt())
                .durationMinutes(activity.getDurationMinutes())
                .distanceKm(activity.getDistanceKm())
                .caloriesBurned(activity.getCaloriesBurned())
                .notes(activity.getNotes())
                .createdAt(activity.getCreatedAt())
                .updatedAt(activity.getUpdatedAt())
                .build();
    }
}