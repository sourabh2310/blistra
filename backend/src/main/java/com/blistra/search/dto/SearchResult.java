package com.blistra.search.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SearchResult {
    private String type;
    private String module;
    private UUID id;
    private String title;
    private String subtitle;
    private OffsetDateTime timestamp;
    private String route;
}