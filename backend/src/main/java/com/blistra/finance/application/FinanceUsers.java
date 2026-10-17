package com.blistra.finance.application;

import com.blistra.finance.dto.UserSummary;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserProfile;
import com.blistra.users.repository.UserProfileRepository;
import com.blistra.users.repository.UserRepository;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Resolves the public identity (username + display name) of users shown in
 * Finance, in two queries regardless of how many users are involved.
 */
@Component
public class FinanceUsers {

    private final UserRepository userRepository;
    private final UserProfileRepository profileRepository;

    public FinanceUsers(UserRepository userRepository, UserProfileRepository profileRepository) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
    }

    public Map<UUID, UserSummary> summaries(Collection<UUID> ids) {
        Map<UUID, UserSummary> result = new HashMap<>();
        if (ids.isEmpty()) {
            return result;
        }
        Map<UUID, String> names = new HashMap<>();
        for (UserProfile profile : profileRepository.findByUserIdIn(ids)) {
            if (profile.getDisplayName() != null && !profile.getDisplayName().isBlank()) {
                names.put(profile.getUserId(), profile.getDisplayName().trim());
            }
        }
        for (User user : userRepository.findAllById(ids)) {
            result.put(user.getId(), new UserSummary(user.getId(), user.getUsername(),
                    names.getOrDefault(user.getId(), user.getUsername())));
        }
        return result;
    }

    /** Lookup that never returns null, for users deleted since. */
    public static UserSummary of(Map<UUID, UserSummary> users, UUID id) {
        UserSummary summary = users.get(id);
        return summary != null ? summary : new UserSummary(id, "unknown", "Unknown user");
    }
}
