package com.blistra.preferences.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Full-replacement preference update. Either list may be omitted (null) to
 * keep the current value; an explicitly empty home-widget list is rejected
 * (the Day-at-a-glance hero is mandatory).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateAppPreferencesRequest {

    private List<String> bottomNav;
    private List<String> homeWidgets;
}
