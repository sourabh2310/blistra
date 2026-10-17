package com.blistra.appupdate.controller;

import com.blistra.appupdate.application.AppUpdateService;
import com.blistra.appupdate.dto.AppLatestResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Public: the app checks for updates before (and after) signing in. */
@RestController
@RequestMapping("/api/v1/app")
@Tag(name = "App updates", description = "Newest installable app build")
public class AppUpdateController {

    private final AppUpdateService service;

    public AppUpdateController(AppUpdateService service) {
        this.service = service;
    }

    @GetMapping("/latest")
    @Operation(summary = "Newest Android build; 204 when none is known")
    public ResponseEntity<AppLatestResponse> latest(
            @RequestParam(defaultValue = "android") String platform) {
        if (!"android".equalsIgnoreCase(platform)) {
            return ResponseEntity.noContent().build();
        }
        return service.latestAndroid()
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.noContent().build());
    }
}
