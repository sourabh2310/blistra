package com.blistra.health.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.health.domain.AppointmentStatus;
import com.blistra.health.domain.HealthAppointment;
import com.blistra.health.dto.AppointmentRequest;
import com.blistra.health.dto.AppointmentResponse;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.repository.HealthAppointmentRepository;
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
public class AppointmentService {

    private final HealthAppointmentRepository appointmentRepository;
    private final CurrentUserProvider currentUserProvider;

    public AppointmentService(HealthAppointmentRepository appointmentRepository,
                              CurrentUserProvider currentUserProvider) {
        this.appointmentRepository = appointmentRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public PageResponse<AppointmentResponse> list(OffsetDateTime from, OffsetDateTime to, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<HealthAppointment> page = appointmentRepository.search(user.getId(), from, to, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public AppointmentResponse create(AppointmentRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthAppointment appointment = new HealthAppointment();
        appointment.setUser(user);
        build(request, appointment);
        return toResponse(appointmentRepository.save(appointment));
    }

    @Transactional(readOnly = true)
    public AppointmentResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(id, user.getId()));
    }

    public AppointmentResponse update(UUID id, AppointmentRequest request) {
        User user = currentUserProvider.getCurrentUser();
        HealthAppointment appointment = getOwned(id, user.getId());
        build(request, appointment);
        return toResponse(appointmentRepository.save(appointment));
    }

    public void delete(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        HealthAppointment appointment = getOwned(id, user.getId());
        appointmentRepository.delete(appointment);
    }

    private void build(AppointmentRequest request, HealthAppointment appointment) {
        appointment.setTitle(request.getTitle());
        appointment.setScheduledAt(request.getScheduledAt());
        appointment.setLocation(request.getLocation());
        appointment.setNotes(request.getNotes());
        AppointmentStatus status = request.getStatus() == null
                ? AppointmentStatus.SCHEDULED
                : request.getStatus();
        appointment.setStatus(status);
    }

    private HealthAppointment getOwned(UUID id, UUID userId) {
        return appointmentRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Appointment not found"));
    }

    private AppointmentResponse toResponse(HealthAppointment appointment) {
        return AppointmentResponse.builder()
                .id(appointment.getId())
                .title(appointment.getTitle())
                .scheduledAt(appointment.getScheduledAt())
                .location(appointment.getLocation())
                .notes(appointment.getNotes())
                .status(appointment.getStatus())
                .createdAt(appointment.getCreatedAt())
                .updatedAt(appointment.getUpdatedAt())
                .build();
    }
}