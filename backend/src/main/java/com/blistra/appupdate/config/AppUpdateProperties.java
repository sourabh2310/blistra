package com.blistra.appupdate.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Where the app looks for new Android builds.
 *
 * @param githubRepo        "owner/name" whose releases carry the APK; empty disables the check
 * @param githubToken       optional token, only to raise GitHub's anonymous rate limit
 * @param tagPrefix         release tags look like {@code apk-<buildNumber>} (see android-apk.yml)
 * @param apkAssetName      file attached to each release
 * @param minSupportedBuild builds below this must update before they can be used
 * @param cacheTtl          how long one GitHub answer is reused
 */
@ConfigurationProperties(prefix = "blistra.app-update")
public record AppUpdateProperties(
        String githubRepo,
        String githubToken,
        String tagPrefix,
        String apkAssetName,
        int minSupportedBuild,
        Duration cacheTtl
) {
    public AppUpdateProperties {
        githubRepo = githubRepo == null ? "" : githubRepo.trim();
        tagPrefix = tagPrefix == null || tagPrefix.isBlank() ? "apk-" : tagPrefix;
        apkAssetName = apkAssetName == null || apkAssetName.isBlank() ? "blistra.apk" : apkAssetName;
        cacheTtl = cacheTtl == null ? Duration.ofMinutes(10) : cacheTtl;
    }
}
