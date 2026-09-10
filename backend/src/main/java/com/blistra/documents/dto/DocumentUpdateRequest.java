package com.blistra.documents.dto;

import com.blistra.documents.domain.DocumentCategory;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentUpdateRequest {
    private DocumentCategory category;

    @Size(max = 1000, message = "Description must be at most 1000 characters")
    private String description;
}