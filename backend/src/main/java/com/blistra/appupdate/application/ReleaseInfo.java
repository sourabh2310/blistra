package com.blistra.appupdate.application;

import java.time.Instant;

/** One published release with its APK asset (null fields when absent). */
public record ReleaseInfo(
        String tag,
        String name,
        String notes,
        boolean draft,
        boolean prerelease,
        Instant publishedAt,
        String assetName,
        String assetUrl,
        Long assetSize
) {}
