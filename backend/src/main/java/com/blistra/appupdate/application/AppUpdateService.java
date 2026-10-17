package com.blistra.appupdate.application;

import com.blistra.appupdate.config.AppUpdateProperties;
import com.blistra.appupdate.dto.AppLatestResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * Finds the newest Android build: the release whose tag is
 * {@code <tagPrefix><buildNumber>} with the highest number and an APK
 * attached. Answers are cached so app launches never hammer GitHub; if
 * GitHub is unreachable the last good answer keeps being served.
 */
@Slf4j
@Service
public class AppUpdateService {

    private static final int MAX_NOTES = 1500;

    private final ReleaseSource source;
    private final AppUpdateProperties properties;
    private final Clock clock;

    private volatile Optional<AppLatestResponse> cached = Optional.empty();
    private volatile Instant cachedAt = Instant.EPOCH;

    @Autowired
    public AppUpdateService(ReleaseSource source, AppUpdateProperties properties) {
        this(source, properties, Clock.systemUTC());
    }

    AppUpdateService(ReleaseSource source, AppUpdateProperties properties, Clock clock) {
        this.source = source;
        this.properties = properties;
        this.clock = clock;
    }

    public Optional<AppLatestResponse> latestAndroid() {
        Instant now = clock.instant();
        if (cachedAt.plus(properties.cacheTtl()).isAfter(now)) {
            return cached;
        }
        synchronized (this) {
            if (cachedAt.plus(properties.cacheTtl()).isAfter(now)) {
                return cached;
            }
            try {
                cached = pick(source.recentReleases());
            } catch (RuntimeException e) {
                // Keep serving the last good answer; retry after the TTL.
                log.warn("Could not refresh app releases: {}", e.getMessage());
            }
            cachedAt = now;
            return cached;
        }
    }

    Optional<AppLatestResponse> pick(List<ReleaseInfo> releases) {
        return releases.stream()
                .filter(r -> !r.draft() && !r.prerelease() && r.assetUrl() != null)
                .filter(r -> r.assetUrl().startsWith("https://"))
                .filter(r -> buildNumberOf(r.tag()) > 0)
                .max(Comparator.comparingInt(r -> buildNumberOf(r.tag())))
                .map(r -> new AppLatestResponse(
                        buildNumberOf(r.tag()),
                        r.name() == null || r.name().isBlank() ? r.tag() : r.name(),
                        truncate(r.notes()),
                        r.assetUrl(),
                        r.assetSize(),
                        r.publishedAt(),
                        properties.minSupportedBuild()));
    }

    int buildNumberOf(String tag) {
        if (tag == null || !tag.startsWith(properties.tagPrefix())) return -1;
        try {
            return Integer.parseInt(tag.substring(properties.tagPrefix().length()));
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    private static String truncate(String notes) {
        if (notes == null) return null;
        String trimmed = notes.strip();
        return trimmed.length() <= MAX_NOTES ? trimmed : trimmed.substring(0, MAX_NOTES) + "…";
    }
}
