package com.blistra.planner.dto;

import java.util.List;

/**
 * A stable page envelope returned by collection endpoints. Keeps the pagination
 * contract explicit and independent of Spring's internal Page type.
 */
public record PageResponse<T>(List<T> content, int page, int size, long totalElements, int totalPages, boolean last) {

    public static <T> PageResponse<T> of(org.springframework.data.domain.Page<T> page) {
        return new PageResponse<>(
                page.getContent(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages(),
                page.isLast());
    }
}