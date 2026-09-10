package com.blistra.notifications.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.notifications.domain.DeviceRegistration;
import com.blistra.notifications.dto.DeviceRegistrationRequest;
import com.blistra.notifications.dto.DeviceRegistrationResponse;
import com.blistra.notifications.repository.DeviceRegistrationRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Device registration service.
 *
 * <p>Push tokens are sensitive credentials: they are stored for future push
 * delivery but never returned by any API and never logged. A user can only
 * register or remove their own devices.</p>
 */
@Service
@Transactional
public class DeviceRegistrationService {

    private final DeviceRegistrationRepository deviceRegistrationRepository;
    private final CurrentUserProvider currentUserProvider;

    public DeviceRegistrationService(DeviceRegistrationRepository deviceRegistrationRepository,
                                     CurrentUserProvider currentUserProvider) {
        this.deviceRegistrationRepository = deviceRegistrationRepository;
        this.currentUserProvider = currentUserProvider;
    }

    /**
     * Registers (or refreshes) a device for the current user, upserting on the
     * user+device natural key so repeated registrations do not create duplicates.
     */
    public DeviceRegistrationResponse register(DeviceRegistrationRequest request) {
        User user = currentUserProvider.getCurrentUser();

        DeviceRegistration registration = deviceRegistrationRepository
                .findByUserIdAndDeviceId(user.getId(), request.getDeviceId())
                .orElseGet(DeviceRegistration::new);

        registration.setUserId(user.getId());
        registration.setDeviceId(request.getDeviceId());
        registration.setPushToken(request.getPushToken());
        registration.setPlatform(request.getPlatform());
        registration.setActive(true);
        registration.setLastSeenAt(LocalDateTime.now());

        return toResponse(deviceRegistrationRepository.save(registration));
    }

    @Transactional(readOnly = true)
    public List<DeviceRegistrationResponse> list() {
        User user = currentUserProvider.getCurrentUser();
        return deviceRegistrationRepository.findByUserId(user.getId())
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public void remove(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        DeviceRegistration registration = deviceRegistrationRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Device registration not found"));
        deviceRegistrationRepository.delete(registration);
    }

    private DeviceRegistrationResponse toResponse(DeviceRegistration registration) {
        return DeviceRegistrationResponse.builder()
                .id(registration.getId())
                .deviceId(registration.getDeviceId())
                .platform(registration.getPlatform())
                .active(registration.isActive())
                .createdAt(registration.getCreatedAt())
                .updatedAt(registration.getUpdatedAt())
                .lastSeenAt(registration.getLastSeenAt())
                .build();
    }
}