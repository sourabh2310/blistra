package com.blistra.appupdate.dto;

import java.time.Instant;

/**
 * Newest installable Android build. Clients compare {@code buildNumber} with
 * their own and must update when theirs is below {@code minSupportedBuild}.
 */
public record AppLatestResponse(
        int buildNumber,
        String versionName,
        String notes,
        String downloadUrl,
        Long sizeBytes,
        Instant publishedAt,
        int minSupportedBuild
) {}
