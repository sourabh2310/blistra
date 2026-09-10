package com.blistra.notifications.dto;

import com.blistra.notifications.domain.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Device registration request. The push token is a sensitive credential: it is
 * accepted for storage and never returned by any API. The owning user is
 * derived from the authenticated context.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeviceRegistrationRequest {

    @NotBlank(message = "Device id is required")
    @Size(max = 255, message = "Device id must be at most 255 characters")
    private String deviceId;

    @NotBlank(message = "Push token is required")
    @Size(max = 512, message = "Push token must be at most 512 characters")
    private String pushToken;

    @NotNull(message = "Platform is required")
    private DevicePlatform platform;
}