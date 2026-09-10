package com.blistra.notifications.repository;

import com.blistra.notifications.domain.DeviceRegistration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeviceRegistrationRepository extends JpaRepository<DeviceRegistration, UUID> {

    Optional<DeviceRegistration> findByUserIdAndDeviceId(UUID userId, String deviceId);

    Optional<DeviceRegistration> findByIdAndUserId(UUID id, UUID userId);

    List<DeviceRegistration> findByUserId(UUID userId);
}