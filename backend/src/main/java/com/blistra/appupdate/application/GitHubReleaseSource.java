package com.blistra.appupdate.application;

import com.blistra.appupdate.config.AppUpdateProperties;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/** Reads releases from the GitHub REST API (public repositories need no token). */
@Component
public class GitHubReleaseSource implements ReleaseSource {

    private final AppUpdateProperties properties;
    private final JsonMapper jsonMapper;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();

    public GitHubReleaseSource(AppUpdateProperties properties, JsonMapper jsonMapper) {
        this.properties = properties;
        this.jsonMapper = jsonMapper;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record GhAsset(String name,
                   @JsonProperty("browser_download_url") String browserDownloadUrl,
                   Long size) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    record GhRelease(@JsonProperty("tag_name") String tagName,
                     String name,
                     String body,
                     boolean draft,
                     boolean prerelease,
                     @JsonProperty("published_at") String publishedAt,
                     List<GhAsset> assets) {}

    @Override
    public List<ReleaseInfo> recentReleases() {
        if (properties.githubRepo().isEmpty()) {
            return List.of();
        }
        HttpRequest.Builder request = HttpRequest.newBuilder(URI.create(
                        "https://api.github.com/repos/" + properties.githubRepo() + "/releases?per_page=20"))
                .timeout(Duration.ofSeconds(8))
                .header("Accept", "application/vnd.github+json")
                .header("X-GitHub-Api-Version", "2022-11-28");
        if (properties.githubToken() != null && !properties.githubToken().isBlank()) {
            request.header("Authorization", "Bearer " + properties.githubToken());
        }
        HttpResponse<String> response;
        try {
            response = http.send(request.build(), HttpResponse.BodyHandlers.ofString());
        } catch (IOException e) {
            throw new IllegalStateException("GitHub releases unreachable", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while reading GitHub releases", e);
        }
        if (response.statusCode() != 200) {
            throw new IllegalStateException("GitHub releases returned HTTP " + response.statusCode());
        }
        GhRelease[] releases = jsonMapper.readValue(response.body(), GhRelease[].class);
        List<ReleaseInfo> result = new ArrayList<>();
        for (GhRelease r : releases) {
            GhAsset apk = r.assets() == null ? null : r.assets().stream()
                    .filter(a -> properties.apkAssetName().equals(a.name()))
                    .findFirst().orElse(null);
            result.add(new ReleaseInfo(
                    r.tagName(), r.name(), r.body(), r.draft(), r.prerelease(),
                    r.publishedAt() == null ? null : Instant.parse(r.publishedAt()),
                    apk == null ? null : apk.name(),
                    apk == null ? null : apk.browserDownloadUrl(),
                    apk == null ? null : apk.size()));
        }
        return result;
    }
}
