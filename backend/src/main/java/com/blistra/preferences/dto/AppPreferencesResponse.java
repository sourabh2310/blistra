package com.blistra.preferences.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Authenticated user's Home/navigation preferences. Never includes the owning
 * user id; ownership is not a client concern.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AppPreferencesResponse {

    private List<String> bottomNav;
    private List<String> homeWidgets;
    private LocalDateTime updatedAt;
}
