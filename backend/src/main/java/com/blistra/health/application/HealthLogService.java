package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthSymptomLog;
import com.blistra.health.dto.HealthLogRequest;
import com.blistra.health.dto.HealthLogResponse;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.repository.HealthSymptomLogRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
@Transactional
public class HealthLogService {

    private final HealthSymptomLogRepository logRepository;
    private final CurrentUserProvider currentUserProvider;

    public HealthLogService(HealthSymptomLogRepository logRepository,
                            CurrentUserProvider currentUserProvider) {
        this.logRepository = logRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<HealthLogResponse> list(OffsetDateTime from, OffsetDateTime to, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Pageable unsorted = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize());
        Page<HealthSymptomLog> page = logRepository.search(user.getId(), from, to, unsorted);
        return PageResponse.of(page.map(this::toResponse));
    }

    public HealthLogResponse create(HealthLogRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthSymptomLog log = new HealthSymptomLog();
        log.setUser(user);
        log.setTitle(request.getTitle());
        log.setDescription(request.getDescription());
        log.setObservedAt(request.getObservedAt());
        log.setSeverity(request.getSeverity());
        log.setNotes(request.getNotes());
        return toResponse(logRepository.save(log));
    }

    @Transactional(readOnly = true)
    public HealthLogResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public HealthLogResponse update(UUID id, HealthLogRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthSymptomLog log = getOwned(id, user.getId());
        log.setTitle(request.getTitle());
        log.setDescription(request.getDescription());
        log.setObservedAt(request.getObservedAt());
        log.setSeverity(request.getSeverity());
        log.setNotes(request.getNotes());
        return toResponse(logRepository.save(log));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthSymptomLog log = getOwned(id, user.getId());
        logRepository.delete(log);
    }

    private HealthSymptomLog getOwned(UUID id, UUID userId) {
        return logRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Health log not found"));
    }

    private HealthLogResponse toResponse(HealthSymptomLog log) {
        return HealthLogResponse.builder()
                .id(log.getId())
                .title(log.getTitle())
                .description(log.getDescription())
                .observedAt(log.getObservedAt())
                .severity(log.getSeverity())
                .notes(log.getNotes())
                .createdAt(log.getCreatedAt())
                .updatedAt(log.getUpdatedAt())
                .build();
    }
}