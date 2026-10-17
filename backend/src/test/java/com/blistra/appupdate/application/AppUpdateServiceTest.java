package com.blistra.appupdate.application;

import com.blistra.appupdate.config.AppUpdateProperties;
import com.blistra.appupdate.dto.AppLatestResponse;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;

class AppUpdateServiceTest {

    private static final AppUpdateProperties PROPS =
            new AppUpdateProperties("owner/repo", null, null, null, 3, Duration.ofMinutes(10));

    private static ReleaseInfo apk(String tag, boolean prerelease) {
        return new ReleaseInfo(tag, "Blistra APK " + tag, "notes " + tag, false, prerelease,
                Instant.parse("2026-10-17T12:00:00Z"), "blistra.apk",
                "https://github.com/owner/repo/releases/download/" + tag + "/blistra.apk", 1234L);
    }

    @Test
    void picksHighestBuildWithApkAndIgnoresOthers() {
        AppUpdateService service = new AppUpdateService(List::of, PROPS);
        List<ReleaseInfo> releases = List.of(
                apk("apk-4", false),
                apk("apk-12", true),                       // prerelease: skipped
                apk("v2.0", false),                        // not a build tag
                new ReleaseInfo("apk-9", "no file", null, false, false, null, null, null, null),
                apk("apk-10", false));

        AppLatestResponse latest = service.pick(releases).orElseThrow();
        assertThat(latest.buildNumber()).isEqualTo(10);
        assertThat(latest.downloadUrl()).endsWith("/apk-10/blistra.apk");
        assertThat(latest.minSupportedBuild()).isEqualTo(3);
        assertThat(latest.sizeBytes()).isEqualTo(1234L);
    }

    @Test
    void cachesAndKeepsLastGoodAnswerWhenSourceFails() {
        AtomicInteger calls = new AtomicInteger();
        List<Boolean> fail = new ArrayList<>(List.of(false));
        ReleaseSource source = () -> {
            calls.incrementAndGet();
            if (fail.get(0)) throw new IllegalStateException("down");
            return List.of(apk("apk-5", false));
        };
        Instant start = Instant.parse("2026-10-17T12:00:00Z");
        Clock[] clock = {Clock.fixed(start, ZoneOffset.UTC)};
        AppUpdateService service = new AppUpdateService(source, PROPS, new Clock() {
            @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
            @Override public Clock withZone(java.time.ZoneId zone) { return this; }
            @Override public Instant instant() { return clock[0].instant(); }
        });

        assertThat(service.latestAndroid()).isPresent();
        assertThat(service.latestAndroid()).isPresent();
        assertThat(calls.get()).isEqualTo(1);

        fail.set(0, true);
        clock[0] = Clock.fixed(start.plus(Duration.ofMinutes(11)), ZoneOffset.UTC);
        assertThat(service.latestAndroid().orElseThrow().buildNumber()).isEqualTo(5);
        assertThat(calls.get()).isEqualTo(2);
    }
}
