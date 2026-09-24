package com.blistra.preferences.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.preferences.domain.UserAppPreferences;
import com.blistra.preferences.dto.AppPreferencesResponse;
import com.blistra.preferences.dto.UpdateAppPreferencesRequest;
import com.blistra.preferences.repository.UserAppPreferencesRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class AppPreferencesService {

    public static final List<String> ALLOWED_NAV =
            List.of("HOME", "PLANNER", "ADD", "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE", "HUB");

    public static final List<String> ALLOWED_WIDGETS = List.of(
            "TODAY_OVERVIEW", "TODAYS_SCHEDULE", "NEEDS_ATTENTION", "YOUR_LIFE", "THIS_WEEK",
            "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE");

    public static final int MAX_NAV_ITEMS = 5;

    public static final List<String> DEFAULT_NAV = List.of("HOME", "PLANNER", "ADD", "HUB", "HEALTH");

    public static final List<String> DEFAULT_WIDGETS = List.of(
            "TODAY_OVERVIEW", "TODAYS_SCHEDULE", "NEEDS_ATTENTION", "YOUR_LIFE", "THIS_WEEK",
            "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE");

    private static final Set<String> MODULE_WIDGETS = Set.of(
            "HEALTH", "MEDICINES", "DIET", "HABITS", "FINANCE");

    private static final List<String> LEGACY_DEFAULT_WIDGETS = List.of(
            "DAY_AT_A_GLANCE", "HEALTH", "MEDICINES", "DIET", "HABITS", "PLANNER", "FINANCE");

    private static final Map<String, String> LEGACY_WIDGET_ALIASES = Map.of(
            "DAY_AT_A_GLANCE", "TODAY_OVERVIEW",
            "PLANNER", "TODAYS_SCHEDULE");

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
        } else {
            prefs.setBottomNav(join(normalizeStoredNav(prefs.getBottomNav())));
        }
        if (request.getHomeWidgets() != null) {
            prefs.setHomeWidgets(join(normalizeWidgets(request.getHomeWidgets())));
        } else {
            prefs.setHomeWidgets(join(normalizeStoredWidgets(prefs.getHomeWidgets())));
        }
        prefs.setUpdatedAt(LocalDateTime.now());
        return toResponse(repository.save(prefs));
    }

    private UserAppPreferences existingOrDefault(User user) {
        return repository.findById(user.getId())
                .orElseGet(() -> new UserAppPreferences(
                        user.getId(), join(DEFAULT_NAV), join(DEFAULT_WIDGETS)));
    }

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
        List<String> ordered = new ArrayList<>(new LinkedHashSet<>(cleaned));
        if (!ordered.contains("HOME")) {
            throw new BadRequestException("HOME cannot be removed from navigation");
        }
        if (!ordered.contains("ADD")) {
            throw new BadRequestException("ADD cannot be removed from navigation");
        }
        if (ordered.size() > MAX_NAV_ITEMS) {
            throw new BadRequestException("At most " + MAX_NAV_ITEMS + " navigation items allowed");
        }
        return centerAdd(ordered);
    }

    public static List<String> normalizeWidgets(List<String> raw) {
        if (raw == null || raw.isEmpty()) {
            throw new BadRequestException("homeWidgets must contain at least one content section or module");
        }
        List<String> cleaned = clean(raw);
        for (String id : cleaned) {
            if (!ALLOWED_WIDGETS.contains(id)) {
                throw new BadRequestException("Unknown home widget: " + id);
            }
        }
        List<String> ordered = new ArrayList<>(new LinkedHashSet<>(cleaned));
        if (ordered.isEmpty()) {
            throw new BadRequestException("homeWidgets must contain at least one content section or module");
        }
        boolean hasModule = ordered.stream().anyMatch(MODULE_WIDGETS::contains);
        boolean hasLifeSection = ordered.contains("YOUR_LIFE");
        if (hasModule && !hasLifeSection) {
            int firstModule = 0;
            while (firstModule < ordered.size() && !MODULE_WIDGETS.contains(ordered.get(firstModule))) {
                firstModule++;
            }
            ordered.add(firstModule, "YOUR_LIFE");
        }
        return ordered;
    }

    static List<String> normalizeStoredNav(String stored) {
        List<String> known = split(stored).stream().filter(ALLOWED_NAV::contains).toList();
        List<String> ordered = new ArrayList<>(new LinkedHashSet<>(known));
        if (!ordered.contains("HOME")) {
            ordered.add(0, "HOME");
        }
        if (!ordered.contains("ADD")) {
            int homeIndex = ordered.indexOf("HOME") + 1;
            ordered.add(homeIndex, "ADD");
        }
        return centerAdd(ordered);
    }

    static List<String> normalizeStoredWidgets(String stored) {
        List<String> split = split(stored);
        if (split.equals(LEGACY_DEFAULT_WIDGETS)) {
            return DEFAULT_WIDGETS;
        }
        List<String> mapped = new ArrayList<>();
        for (String token : split) {
            if (ALLOWED_WIDGETS.contains(token)) {
                mapped.add(token);
            } else if (LEGACY_WIDGET_ALIASES.containsKey(token)) {
                mapped.add(LEGACY_WIDGET_ALIASES.get(token));
            }
        }
        if (mapped.isEmpty()) {
            return DEFAULT_WIDGETS;
        }
        return normalizeWidgets(mapped);
    }

    private static List<String> centerAdd(List<String> ids) {
        List<String> optional = ids.stream()
                .filter(id -> !id.equals("HOME") && !id.equals("ADD"))
                .toList();
        int before = Math.max(0, (optional.size() - 1) / 2);
        List<String> limited = optional.subList(0, Math.min(MAX_NAV_ITEMS - 2, optional.size()));
        List<String> ordered = new ArrayList<>();
        ordered.add("HOME");
        ordered.addAll(limited.subList(0, Math.min(before, limited.size())));
        ordered.add("ADD");
        ordered.addAll(limited.subList(Math.min(before, limited.size()), limited.size()));
        return ordered;
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
                .bottomNav(normalizeStoredNav(prefs.getBottomNav()))
                .homeWidgets(normalizeStoredWidgets(prefs.getHomeWidgets()))
                .updatedAt(prefs.getUpdatedAt())
                .build();
    }
}
