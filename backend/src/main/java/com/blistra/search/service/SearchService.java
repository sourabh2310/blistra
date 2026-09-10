package com.blistra.search.service;

import com.blistra.common.exception.BadRequestException;
import com.blistra.search.dto.SearchResponse;
import com.blistra.search.dto.SearchResult;
import com.blistra.search.repository.UnifiedSearchRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
public class SearchService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final int MIN_QUERY_LENGTH = 2;

    private final CurrentUserProvider currentUserProvider;
    private final UnifiedSearchRepository repository;

    public SearchService(CurrentUserProvider currentUserProvider,
                         UnifiedSearchRepository repository) {
        this.currentUserProvider = currentUserProvider;
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public SearchResponse search(String query, String type, OffsetDateTime from, OffsetDateTime to,
                                 int page, int size) {
        if (query == null || query.trim().length() < MIN_QUERY_LENGTH) {
            return SearchResponse.builder()
                    .results(List.of())
                    .page(Math.max(page, 0))
                    .size(size)
                    .totalElements(0)
                    .totalPages(0)
                    .last(true)
                    .build();
        }

        String normalizedType = UnifiedSearchRepository.normalizeModule(type);
        if (type != null && !type.isBlank() && normalizedType == null) {
            throw new BadRequestException("Invalid search type: " + type);
        }
        if (page < 0) {
            throw new BadRequestException("page must be >= 0");
        }
        if (size <= 0) {
            throw new BadRequestException("size must be > 0");
        }
        if (size > MAX_PAGE_SIZE) {
            throw new BadRequestException("size must not exceed " + MAX_PAGE_SIZE);
        }
        if (from != null && to != null && from.isAfter(to)) {
            throw new BadRequestException("from must not be after to");
        }

        UUID userId = currentUserProvider.getCurrentUser().getId();
        String term = "%" + query.trim().toLowerCase() + "%";
        Set<String> modules = normalizedType == null ? UnifiedSearchRepository.allModules() : Set.of(normalizedType);

        long totalElements = repository.count(userId, modules, term, from, to);
        int totalPages = (int) Math.ceil((double) totalElements / size);
        // Long arithmetic: page * size can overflow int for adversarial input.
        long offsetLong = (long) page * (long) size;

        List<SearchResult> pageResults;
        if (offsetLong >= totalElements || offsetLong > Integer.MAX_VALUE) {
            pageResults = List.of();
        } else {
            pageResults = repository.findPage(userId, modules, term, from, to, size, (int) offsetLong)
                    .stream()
                    .map(row -> SearchResult.builder()
                            .module(row.module())
                            .type(row.resultType())
                            .id(row.id())
                            .title(row.title())
                            .subtitle(row.subtitle())
                            .timestamp(row.ts())
                            .route(routeFor(row.module(), row.resultType(), row.id()))
                            .build())
                    .toList();
        }

        boolean last = totalElements == 0 || page >= totalPages - 1;
        return SearchResponse.builder()
                .results(pageResults)
                .page(page)
                .size(size)
                .totalElements(totalElements)
                .totalPages(totalPages)
                .last(last)
                .build();
    }

    private String routeFor(String module, String resultType, UUID id) {
        return switch (module) {
            case "PLANNER" -> switch (resultType) {
                case "TASK" -> "planner/task/" + id;
                case "TASK_LIST" -> "planner/list/" + id;
                default -> "planner/event/" + id;
            };
            case "MEDICINES" -> "medicines/" + id;
            case "HEALTH" -> switch (resultType) {
                case "HEALTH_EVENT" -> "health/event/" + id;
                case "HEALTH_APPOINTMENT" -> "health/appointment/" + id;
                case "SYMPTOM_LOG" -> "health/symptom/" + id;
                case "HEALTH_ACTIVITY" -> "health/activity/" + id;
                case "HEALTH_MEASUREMENT" -> "health/measurement/" + id;
                default -> "health/sleep/" + id;
            };
            case "DIET" -> switch (resultType) {
                case "MEAL" -> "diet/meal/" + id;
                case "MEAL_ITEM" -> "diet/meal/item/" + id;
                case "DIET_PROFILE" -> "diet/profile";
                default -> "diet/water/" + id;
            };
            case "HABITS" -> "habits/" + id;
            case "FINANCE" -> switch (resultType) {
                case "ACCOUNT" -> "finance/accounts/" + id;
                case "CATEGORY" -> "finance/categories/" + id;
                case "TRANSFER" -> "finance/transfers/" + id;
                default -> "finance/transactions/" + id;
            };
            case "DOCUMENTS" -> "documents/" + id;
            default -> "";
        };
    }
}