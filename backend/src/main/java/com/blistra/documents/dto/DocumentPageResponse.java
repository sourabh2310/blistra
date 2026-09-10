package com.blistra.documents.dto;

import com.blistra.documents.domain.Document;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.stream.Collectors;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentPageResponse {
    private List<DocumentResponse> content;
    private int page;
    private int size;
    private long totalElements;
    private int totalPages;

    public static DocumentPageResponse of(Page<Document> page) {
        return DocumentPageResponse.builder()
                .content(page.getContent().stream()
                        .map(DocumentResponse::fromEntity)
                        .collect(Collectors.toList()))
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .build();
    }
}