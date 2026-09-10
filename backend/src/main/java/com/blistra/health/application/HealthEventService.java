package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.HealthEvent;
import com.blistra.health.dto.HealthEventRequest;
import com.blistra.health.dto.HealthEventResponse;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.repository.HealthEventRepository;
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
public class HealthEventService {

    private final HealthEventRepository eventRepository;
    private final CurrentUserProvider currentUserProvider;

    public HealthEventService(HealthEventRepository eventRepository,
                              CurrentUserProvider currentUserProvider) {
        this.eventRepository = eventRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<HealthEventResponse> list(OffsetDateTime from, OffsetDateTime to, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<HealthEvent> page = eventRepository.search(user.getId(), from, to, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public HealthEventResponse create(HealthEventRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthEvent event = new HealthEvent();
        event.setUser(user);
        event.setType(request.getType());
        event.setTitle(request.getTitle());
        event.setOccurredAt(request.getOccurredAt());
        event.setNotes(request.getNotes());
        return toResponse(eventRepository.save(event));
    }

    @Transactional(readOnly = true)
    public HealthEventResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public HealthEventResponse update(UUID id, HealthEventRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthEvent event = getOwned(id, user.getId());
        event.setType(request.getType());
        event.setTitle(request.getTitle());
        event.setOccurredAt(request.getOccurredAt());
        event.setNotes(request.getNotes());
        return toResponse(eventRepository.save(event));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthEvent event = getOwned(id, user.getId());
        eventRepository.delete(event);
    }

    private HealthEvent getOwned(UUID id, UUID userId) {
        return eventRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Health event not found"));
    }

    private HealthEventResponse toResponse(HealthEvent event) {
        return HealthEventResponse.builder()
                .id(event.getId())
                .type(event.getType())
                .title(event.getTitle())
                .occurredAt(event.getOccurredAt())
                .notes(event.getNotes())
                .createdAt(event.getCreatedAt())
                .updatedAt(event.getUpdatedAt())
                .build();
    }
}