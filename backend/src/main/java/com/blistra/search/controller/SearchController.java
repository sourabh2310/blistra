package com.blistra.search.controller;

import com.blistra.search.dto.SearchResponse;
import com.blistra.search.service.SearchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/v1/search")
@Tag(name = "Search", description = "Unified search across personal data")
public class SearchController {

    @Autowired
    private SearchService searchService;

    @GetMapping
    @Operation(summary = "Search personal data", description = "Search across all modules for the authenticated user")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Search results",
                    content = @Content(schema = @Schema(implementation = SearchResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid query"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<SearchResponse> search(
            @Parameter(description = "Search query (minimum 2 characters)", required = true)
            @RequestParam String q,
            @Parameter(description = "Module filter (PLANNER, MEDICINES, HEALTH, DIET)")
            @RequestParam(required = false) String type,
            @Parameter(description = "Start date for filtering")
            @RequestParam(required = false) OffsetDateTime from,
            @Parameter(description = "End date for filtering")
            @RequestParam(required = false) OffsetDateTime to,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size (max 50)")
            @RequestParam(defaultValue = "20") int size) {

        SearchResponse response = searchService.search(q, type, from, to, page, size);
        return ResponseEntity.ok(response);
    }
}