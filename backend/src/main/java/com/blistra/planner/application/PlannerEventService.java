package com.blistra.planner.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.planner.domain.EventStatus;
import com.blistra.planner.domain.PlannerEvent;
import com.blistra.planner.dto.EventCreateRequest;
import com.blistra.planner.dto.EventResponse;
import com.blistra.planner.dto.EventUpdateRequest;
import com.blistra.planner.dto.PageResponse;
import com.blistra.planner.repository.PlannerEventRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional
public class PlannerEventService {

    private static final int MAX_PAGE_SIZE = 50;

    private final PlannerEventRepository eventRepository;
    private final CurrentUserProvider currentUserProvider;
    private final PlannerTime time;

    public PlannerEventService(PlannerEventRepository eventRepository,
                               CurrentUserProvider currentUserProvider,
                               PlannerTime time) {
        this.eventRepository = eventRepository;
        this.currentUserProvider = currentUserProvider;
        this.time = time;
    }

    @Transactional(readOnly = true)
    public PageResponse<EventResponse> list(Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        int size = Math.min(Math.max(pageable.getPageSize(), 1), MAX_PAGE_SIZE);
        Sort sort = pageable.getSort().isSorted() ? pageable.getSort() : Sort.by(Sort.Order.asc("startAt"));
        Pageable safePageable = PageRequest.of(pageable.getPageNumber(), size, sort);
        Page<PlannerEvent> page = eventRepository.findByUserId(user.getId(), safePageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public EventResponse create(EventCreateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        validateRange(request.getStartAt(), request.getEndAt());

        PlannerEvent event = new PlannerEvent();
        event.setUser(user);
        applyFields(request.getTitle(), request.getDescription(), request.getLocation(),
                request.getStartAt(), request.getEndAt(), event);
        event.setStatus(request.getStatus() != null ? request.getStatus() : EventStatus.SCHEDULED);
        return toResponse(eventRepository.save(event));
    }

    public EventResponse update(UUID eventId, EventUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        PlannerEvent event = getOwned(eventId, user.getId());
        validateRange(request.getStartAt(), request.getEndAt());

        applyFields(request.getTitle(), request.getDescription(), request.getLocation(),
                request.getStartAt(), request.getEndAt(), event);
        if (request.getStatus() != null) {
            event.setStatus(request.getStatus());
        }
        return toResponse(eventRepository.save(event));
    }

    @Transactional(readOnly = true)
    public EventResponse get(UUID eventId) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(eventId, user.getId()));
    }

    public void delete(UUID eventId) {
        User user = currentUserProvider.getCurrentUser();
        PlannerEvent event = getOwned(eventId, user.getId());
        eventRepository.delete(event);
    }

    /**
     * Events overlapping the user's current calendar day, for the Today view.
     */
    @Transactional(readOnly = true)
    public List<EventResponse> eventsForToday(UUID userId) {
        return eventRepository.findOverlapping(userId, EventStatus.CANCELLED, time.todayStart(), time.tomorrowStart())
                .stream().map(this::toResponse).toList();
    }

    /**
     * Events overlapping an explicit calendar window. Used for date navigation
     * and week views so only one day/week is fetched, never a lifetime.
     */
    @Transactional(readOnly = true)
    public List<EventResponse> eventsForRange(UUID userId, java.time.OffsetDateTime startInclusive,
                                              java.time.OffsetDateTime endExclusive) {
        return eventRepository.findOverlapping(userId, EventStatus.CANCELLED, startInclusive, endExclusive)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<EventResponse> eventsForDate(java.time.LocalDate date) {
        User user = currentUserProvider.getCurrentUser();
        return eventsForRange(user.getId(), time.dayStart(date), time.dayEndExclusive(date));
    }

    @Transactional(readOnly = true)
    public List<EventResponse> eventsForRange(java.time.OffsetDateTime from, java.time.OffsetDateTime to) {
        if (from == null || to == null || !to.isAfter(from)) {
            throw new BadRequestException("Invalid range: 'to' must be after 'from'");
        }
        if (java.time.Duration.between(from, to).toDays() > 31) {
            throw new BadRequestException("Range too large: max 31 days");
        }
        User user = currentUserProvider.getCurrentUser();
        return eventsForRange(user.getId(), from, to);
    }

    public EventResponse complete(UUID eventId) {
        return stateAction(eventId, EventStatus.COMPLETED);
    }

    public EventResponse cancel(UUID eventId) {
        return stateAction(eventId, EventStatus.CANCELLED);
    }

    public EventResponse reopen(UUID eventId) {
        return stateAction(eventId, EventStatus.SCHEDULED);
    }

    private EventResponse stateAction(UUID eventId, EventStatus target) {
        User user = currentUserProvider.getCurrentUser();
        PlannerEvent event = getOwned(eventId, user.getId());
        event.setStatus(target);
        return toResponse(eventRepository.save(event));
    }

    private void applyFields(String title, String description, String location,
                             java.time.OffsetDateTime startAt, java.time.OffsetDateTime endAt,
                             PlannerEvent event) {
        event.setTitle(title);
        event.setDescription(description);
        event.setLocation(location);
        event.setStartAt(startAt);
        event.setEndAt(endAt);
    }

    private void validateRange(java.time.OffsetDateTime startAt, java.time.OffsetDateTime endAt) {
        if (!endAt.isAfter(startAt)) {
            throw new BadRequestException("Event end time must be after start time");
        }
    }

    private PlannerEvent getOwned(UUID id, UUID userId) {
        return eventRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found"));
    }

    private EventResponse toResponse(PlannerEvent event) {
        return EventResponse.builder()
                .id(event.getId())
                .title(event.getTitle())
                .description(event.getDescription())
                .location(event.getLocation())
                .startAt(event.getStartAt())
                .endAt(event.getEndAt())
                .status(event.getStatus())
                .createdAt(event.getCreatedAt())
                .updatedAt(event.getUpdatedAt())
                .build();
    }
}