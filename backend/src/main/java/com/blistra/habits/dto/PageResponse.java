package com.blistra.habits.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

/**
 * Uniform pagination envelope for habit collection endpoints.
 *
 * <p>Kept habits-local so the module does not couple to another module's
 * response shape.</p>
 */
public record PageResponse<T>(
        List<T> content,
        @Schema(description = "Current page index (zero based)") int page,
        @Schema(description = "Requested page size") int size,
        @Schema(description = "Total number of elements across all pages") long totalElements,
        @Schema(description = "Total number of pages") int totalPages,
        @Schema(description = "Whether this is the last page") boolean last
) {

    public static <S, T> PageResponse<T> of(Page<S> source, Function<S, T> mapper) {
        List<T> content = source.getContent().stream().map(mapper).toList();
        return new PageResponse<>(content, source.getNumber(), source.getSize(),
                source.getTotalElements(), source.getTotalPages(), source.isLast());
    }

    public static <T> PageResponse<T> of(Page<T> source) {
        return new PageResponse<>(source.getContent(), source.getNumber(), source.getSize(),
                source.getTotalElements(), source.getTotalPages(), source.isLast());
    }
}