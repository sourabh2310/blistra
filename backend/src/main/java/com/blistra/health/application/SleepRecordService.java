package com.blistra.health.application;

import com.blistra.common.exception.InvalidRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthSleepRecord;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.dto.SleepRecordRequest;
import com.blistra.health.dto.SleepRecordResponse;
import com.blistra.health.repository.HealthSleepRecordRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.UUID;

@Service
@Transactional
public class SleepRecordService {

    private static final long MAX_SLEEP_MINUTES = 36 * 60;

    private final HealthSleepRecordRepository sleepRecordRepository;
    private final CurrentUserProvider currentUserProvider;

    public SleepRecordService(HealthSleepRecordRepository sleepRecordRepository,
                              CurrentUserProvider currentUserProvider) {
        this.sleepRecordRepository = sleepRecordRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<SleepRecordResponse> list(OffsetDateTime from, OffsetDateTime to, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<HealthSleepRecord> page = sleepRecordRepository.search(user.getId(), from, to, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public SleepRecordResponse create(SleepRecordRequest request) {
        validate(request);
        User user = currentUserProvider.getCurrentUser();
        HealthSleepRecord record = new HealthSleepRecord();
        record.setUser(user);
        record.setStartedAt(request.getStartedAt());
        record.setEndedAt(request.getEndedAt());
        record.setRating(request.getRating());
        record.setNotes(request.getNotes());
        return toResponse(sleepRecordRepository.save(record));
    }

    @Transactional(readOnly = true)
    public SleepRecordResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public SleepRecordResponse update(UUID id, SleepRecordRequest request) {
        validate(request);
        User user = currentUserProvider.getCurrentUser();
        HealthSleepRecord record = getOwned(id, user.getId());
        record.setStartedAt(request.getStartedAt());
        record.setEndedAt(request.getEndedAt());
        record.setRating(request.getRating());
        record.setNotes(request.getNotes());
        return toResponse(sleepRecordRepository.save(record));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthSleepRecord record = getOwned(id, user.getId());
        sleepRecordRepository.delete(record);
    }

    private void validate(SleepRecordRequest request) {
        if (request.getEndedAt().isBefore(request.getStartedAt())
                || request.getEndedAt().equals(request.getStartedAt())) {
            throw new InvalidRequestException("Sleep end time must be after start time");
        }
        long minutes = Duration.between(request.getStartedAt(), request.getEndedAt()).toMinutes();
        if (minutes > MAX_SLEEP_MINUTES) {
            throw new InvalidRequestException("Sleep duration is outside a plausible range");
        }
    }

    private HealthSleepRecord getOwned(UUID id, UUID userId) {
        return sleepRecordRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Sleep record not found"));
    }

    private SleepRecordResponse toResponse(HealthSleepRecord record) {
        long durationMinutes = Duration.between(record.getStartedAt(), record.getEndedAt()).toMinutes();
        return SleepRecordResponse.builder()
                .id(record.getId())
                .startedAt(record.getStartedAt())
                .endedAt(record.getEndedAt())
                .durationMinutes(durationMinutes)
                .rating(record.getRating())
                .notes(record.getNotes())
                .createdAt(record.getCreatedAt())
                .updatedAt(record.getUpdatedAt())
                .build();
    }
}