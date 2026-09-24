package com.blistra.preferences.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.preferences.domain.UserAppPreferences;
import com.blistra.preferences.dto.AppPreferencesResponse;
import com.blistra.preferences.dto.UpdateAppPreferencesRequest;
import com.blistra.preferences.repository.UserAppPreferencesRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Reads/updates the authenticated user's Home and bottom-navigation
 * preferences. Ownership is derived from the security context; unknown
 * destination/widget identifiers are rejected server-side and never stored.
 */
@Slf4j
@Service
public class AppPreferencesService {

    /** Destinations allowed in the bottom navigation. */
    public static final List<String> ALLOWED_NAV =
            List.of("HOME", "PLANNER", "ADD", "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE", "HUB");

    /** Widgets allowed on Home. DAY_AT_A_GLANCE is the locked hero. */
    public static final List<String> ALLOWED_WIDGETS =
            List.of("DAY_AT_A_GLANCE", "HEALTH", "MEDICINES", "DIET", "HABITS", "PLANNER", "FINANCE");

    public static final int MAX_NAV_ITEMS = 5;

    public static final List<String> DEFAULT_NAV = List.of("HOME", "PLANNER", "ADD", "HEALTH", "HUB");

    public static final List<String> DEFAULT_WIDGETS =
            List.of("DAY_AT_A_GLANCE", "HEALTH", "MEDICINES", "DIET", "HABITS", "PLANNER", "FINANCE");

    private final CurrentUserProvider currentUserProvider;
    private final UserAppPreferencesRepository repository;

    public AppPreferencesService(CurrentUserProvider currentUserProvider,
                                 UserAppPreferencesRepository repository) {
        this.currentUserProvider = currentUserProvider;
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public AppPreferencesResponse get() {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(existingOrDefault(user));
    }

    @Transactional
    public AppPreferencesResponse update(UpdateAppPreferencesRequest request) {
        User user = currentUserProvider.getCurrentUser();
        UserAppPreferences prefs = existingOrDefault(user);
        if (request.getBottomNav() != null) {
            prefs.setBottomNav(join(normalizeNav(request.getBottomNav())));
        }
        if (request.getHomeWidgets() != null) {
            prefs.setHomeWidgets(join(normalizeWidgets(request.getHomeWidgets())));
        }
        prefs.setUpdatedAt(LocalDateTime.now());
        return toResponse(repository.save(prefs));
    }

    private UserAppPreferences existingOrDefault(User user) {
        return repository.findById(user.getId())
                .orElseGet(() -> new UserAppPreferences(
                        user.getId(), join(DEFAULT_NAV), join(DEFAULT_WIDGETS)));
    }

    /**
     * Validates bottom navigation: known ids only, HOME+ADD mandatory,
     * at most 5 items, no duplicates. Hub reachability is guaranteed by the
     * Home surface (always links Hub), so Hub itself may be unpinned.
     */
    public static List<String> normalizeNav(List<String> raw) {
        if (raw == null || raw.isEmpty()) {
            throw new BadRequestException("bottomNav must not be empty");
        }
        List<String> cleaned = clean(raw);
        for (String id : cleaned) {
            if (!ALLOWED_NAV.contains(id)) {
                throw new BadRequestException("Unknown navigation destination: " + id);
            }
        }
        if (!cleaned.contains("HOME")) {
            throw new BadRequestException("HOME cannot be removed from navigation");
        }
        if (!cleaned.contains("ADD")) {
            throw new BadRequestException("ADD cannot be removed from navigation");
        }
        if (cleaned.size() > MAX_NAV_ITEMS) {
            throw new BadRequestException("At most " + MAX_NAV_ITEMS + " navigation items allowed");
        }
        return new ArrayList<>(new LinkedHashSet<>(cleaned));
    }

    /**
     * Validates home widgets: known ids only, DAY_AT_A_GLANCE always first,
     * no duplicates.
     */
    public static List<String> normalizeWidgets(List<String> raw) {
        if (raw == null || raw.isEmpty()) {
            throw new BadRequestException("homeWidgets must not be empty");
        }
        List<String> cleaned = clean(raw);
        for (String id : cleaned) {
            if (!ALLOWED_WIDGETS.contains(id)) {
                throw new BadRequestException("Unknown home widget: " + id);
            }
        }
        Set<String> ordered = new LinkedHashSet<>();
        ordered.add("DAY_AT_A_GLANCE");
        ordered.addAll(cleaned);
        return new ArrayList<>(ordered);
    }

    private static List<String> clean(List<String> raw) {
        List<String> out = new ArrayList<>();
        for (String item : raw) {
            if (item == null) continue;
            String id = item.trim().toUpperCase();
            if (!id.isEmpty()) out.add(id);
        }
        return out;
    }

    private static String join(List<String> ids) {
        return String.join(",", ids);
    }

    private static List<String> split(String stored) {
        if (stored == null || stored.isBlank()) return List.of();
        List<String> out = new ArrayList<>();
        for (String part : stored.split(",")) {
            String id = part.trim().toUpperCase();
            if (!id.isEmpty()) out.add(id);
        }
        return out;
    }

    private static AppPreferencesResponse toResponse(UserAppPreferences prefs) {
        return AppPreferencesResponse.builder()
                .bottomNav(split(prefs.getBottomNav()))
                .homeWidgets(split(prefs.getHomeWidgets()))
                .updatedAt(prefs.getUpdatedAt())
                .build();
    }
}
