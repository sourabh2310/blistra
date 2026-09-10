package com.blistra.documents.controller;

import com.blistra.documents.application.DocumentService;
import com.blistra.documents.domain.DocumentCategory;
import com.blistra.documents.dto.DocumentPageResponse;
import com.blistra.documents.dto.DocumentResponse;
import com.blistra.documents.dto.DocumentUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/v1/documents")
@Tag(name = "Documents", description = "Private document vault endpoints")
public class DocumentController {

    private final DocumentService documentService;

    public DocumentController(DocumentService documentService) {
        this.documentService = documentService;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a document",
            description = "Upload a new document with metadata. File must be PDF, JPEG, or PNG.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Document uploaded successfully",
                    content = @Content(schema = @Schema(implementation = DocumentResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid file or metadata"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "413", description = "File too large")
    })
    public ResponseEntity<DocumentResponse> upload(
            @Parameter(description = "File to upload (PDF, JPEG, PNG)")
            @RequestPart("file") MultipartFile file,

            @Parameter(description = "Document category")
            @RequestParam("category") DocumentCategory category,

            @Parameter(description = "Optional description")
            @RequestParam(value = "description", required = false) String description) {

        DocumentResponse response = documentService.upload(file, category, description);
        return ResponseEntity.status(201).body(response);
    }

    @GetMapping
    @Operation(summary = "List documents",
            description = "List user's documents with optional filtering and pagination")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "List of documents",
                    content = @Content(schema = @Schema(implementation = DocumentPageResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<DocumentPageResponse> list(
            @Parameter(description = "Filter by category")
            @RequestParam(required = false) DocumentCategory category,

            @Parameter(description = "Filter by created date from (ISO-8601)")
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,

            @Parameter(description = "Filter by created date to (ISO-8601)")
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to,

            @Parameter(description = "Page number (0-based)")
            @RequestParam(defaultValue = "0") @Min(0) int page,

            @Parameter(description = "Page size (max 100)")
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {

        DocumentPageResponse response = documentService.list(category, from, to, page, size);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get document metadata",
            description = "Get metadata for a specific document")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Document metadata",
                    content = @Content(schema = @Schema(implementation = DocumentResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Document not found")
    })
    public ResponseEntity<DocumentResponse> get(
            @Parameter(description = "Document ID") @PathVariable UUID id) {

        DocumentResponse response = documentService.get(id);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}/content")
    @Operation(summary = "Download document content",
            description = "Stream the document file content")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "File content streamed"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Document not found")
    })
    public ResponseEntity<Resource> download(
            @Parameter(description = "Document ID") @PathVariable UUID id) {

        var download = documentService.download(id);
        var doc = download.document();
        var resource = download.resource();

        String contentDisposition = com.blistra.documents.support.ContentDispositionBuilder
                .attachment(doc.getOriginalFilename());

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(doc.getContentType()))
                .contentLength(doc.getFileSize())
                .header(HttpHeaders.CONTENT_DISPOSITION, contentDisposition)
                .header(HttpHeaders.X_CONTENT_TYPE_OPTIONS, "nosniff")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(resource);
    }

    @PatchMapping("/{id}")
    @Operation(summary = "Update document metadata",
            description = "Update category and/or description of a document")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Document updated",
                    content = @Content(schema = @Schema(implementation = DocumentResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Document not found")
    })
    public ResponseEntity<DocumentResponse> update(
            @Parameter(description = "Document ID") @PathVariable UUID id,
            @Valid @RequestBody DocumentUpdateRequest request) {

        DocumentResponse response = documentService.update(id, request);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a document",
            description = "Delete a document and its stored file")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Document deleted"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Document not found")
    })
    public ResponseEntity<Void> delete(
            @Parameter(description = "Document ID") @PathVariable UUID id) {

        documentService.delete(id);
        return ResponseEntity.noContent().build();
    }
}