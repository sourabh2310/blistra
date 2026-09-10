package com.blistra.documents.application;

import com.blistra.common.exception.InvalidCredentialsException;
import com.blistra.common.exception.InvalidRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.documents.config.DocumentsProperties;
import com.blistra.documents.domain.Document;
import com.blistra.documents.domain.DocumentCategory;
import com.blistra.documents.dto.DocumentPageResponse;
import com.blistra.documents.dto.DocumentResponse;
import com.blistra.documents.dto.DocumentUpdateRequest;
import com.blistra.documents.repository.DocumentRepository;
import com.blistra.documents.storage.DocumentStorageService;
import com.blistra.documents.storage.DocumentStorageException;
import com.blistra.documents.support.FilenameSanitizer;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;

@Service
@Transactional
public class DocumentService {

    private static final Logger log = LoggerFactory.getLogger(DocumentService.class);

    private final DocumentRepository documentRepository;
    private final DocumentStorageService storage;
    private final DocumentValidator validator;
    private final DocumentsProperties properties;
    private final UserRepository userRepository;

    public DocumentService(DocumentRepository documentRepository,
                           DocumentStorageService storage,
                           DocumentValidator validator,
                           DocumentsProperties properties,
                           UserRepository userRepository) {
        this.documentRepository = documentRepository;
        this.storage = storage;
        this.validator = validator;
        this.properties = properties;
        this.userRepository = userRepository;
    }

    /**
     * Resolves the currently authenticated user from the security context.
     */
    private User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || !(auth.getPrincipal() instanceof UserDetails ud)) {
            throw new InvalidCredentialsException("Authentication required");
        }
        return userRepository.findByEmail(ud.getUsername())
                .orElseThrow(() -> new InvalidCredentialsException("Authentication required"));
    }

    /**
     * Uploads a new document.
     *
     * <p>Filesystem and database operations are <em>not</em> atomic, so the
     * steps are ordered to make partial failure safe:
     * <ol>
     *   <li>file bytes are streamed to storage under a server-generated UUID
     *       key (never derived from the client filename);</li>
     *   <li>metadata is persisted afterwards;</li>
     *   <li>if persistence fails, the orphaned file is deleted on a
     *       best-effort basis and the original error propagates.</li>
     * </ol>
     * A leftover orphan is possible only if both the insert <em>and</em> the
     * compensating file delete fail; that case is logged with the object key.
     */
    public DocumentResponse upload(MultipartFile file,
                                   DocumentCategory category,
                                   String description) {

        User user = getCurrentUser();

        // Validate file content and detect MIME type
        String contentType = validator.validateAndDetect(file);

        // Validate metadata
        validator.validateMetadata(description);

        // Generate unique storage key (never derived from the filename)
        String objectKey = UUID.randomUUID().toString();

        // Sanitize the client-supplied name before persisting it as metadata:
        // strip path components and control characters so a hostile filename
        // can never become a storage path, a header value, or a DB surprise.
        String originalFilename = FilenameSanitizer.sanitize(
                file != null ? file.getOriginalFilename() : null);

        // Compute SHA-256 hash and store in one pass
        String contentHash;
        long size;
        try {
            MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
            try (DigestInputStream dis = new DigestInputStream(file.getInputStream(), sha256)) {
                size = storage.store(objectKey, dis, maxBytes());
            }
            contentHash = HexFormat.of().formatHex(sha256.digest());
        } catch (DocumentStorageException e) {
            throw new InvalidRequestException("Failed to store document", e);
        } catch (IOException e) {
            throw new InvalidRequestException("Failed to read uploaded file", e);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }

        // Persist metadata
        Document doc = new Document(user, originalFilename, objectKey,
                contentType, size, contentHash, category, description);
        try {
            doc = documentRepository.save(doc);
        } catch (RuntimeException e) {
            // Clean up orphaned file on persistence failure
            try {
                storage.delete(objectKey);
            } catch (DocumentStorageException ex) {
                log.warn("Failed to clean up orphaned file after persistence failure: {}", objectKey);
            }
            throw e;
        }

        return toResponse(doc);
    }

    @Transactional(readOnly = true)
    public DocumentPageResponse list(DocumentCategory category,
                                     java.time.LocalDateTime from,
                                     java.time.LocalDateTime to,
                                     int page,
                                     int size) {

        User user = getCurrentUser();

        if (page < 0) page = 0;
        if (size < 1) size = 20;
        if (size > 100) size = 100;

        Pageable pageable = PageRequest.of(page, size);

        Page<Document> result = documentRepository.searchOwned(
                user.getId(), category != null ? category.name() : null, from, to, pageable);

        return DocumentPageResponse.of(result);
    }

    @Transactional(readOnly = true)
    public DocumentResponse get(UUID id) {
        User user = getCurrentUser();
        Document doc = getOwned(id, user.getId());
        return toResponse(doc);
    }

    @Transactional(readOnly = true)
    public DocumentDownload download(UUID id) {
        User user = getCurrentUser();
        Document doc = getOwned(id, user.getId());
        return new DocumentDownload(doc, storage.load(doc.getStoredObjectKey()));
    }

    public DocumentResponse update(UUID id, DocumentUpdateRequest request) {
        User user = getCurrentUser();
        Document doc = getOwned(id, user.getId());

        boolean changed = false;
        if (request.getCategory() != null && request.getCategory() != doc.getCategory()) {
            doc.setCategory(request.getCategory());
            changed = true;
        }
        if (request.getDescription() != null) {
            String desc = request.getDescription().trim();
            String newDesc = desc.isEmpty() ? null : desc;
            if ((doc.getDescription() == null && newDesc != null)
                    || (doc.getDescription() != null && !doc.getDescription().equals(newDesc))) {
                doc.setDescription(newDesc);
                changed = true;
            }
        }
        if (changed) {
            doc = documentRepository.save(doc);
        }
        return toResponse(doc);
    }

    /**
     * Deletes a document's metadata and its stored file.
     *
     * <p>Filesystem and database operations are <em>not</em> atomic. The
     * ordering is deliberate: metadata is deleted first, then the file.
     * <ul>
     *   <li>If the metadata delete fails, the file is never touched (no
     *       orphaned metadata, file intact).</li>
     *   <li>If the file delete fails, this method throws and the surrounding
     *       transaction rolls back, restoring the metadata row — the document
     *       remains fully present and the delete can be retried. The metadata
     *       is therefore <em>not</em> lost in this path.</li>
     *   <li>File deletion is idempotent: an already-absent file is not an
     *       error.</li>
     * </ul>
     */
    public void delete(UUID id) {
        User user = getCurrentUser();
        Document doc = getOwned(id, user.getId());

        // Delete metadata first (DB)
        documentRepository.delete(doc);

        // Then delete physical file
        try {
            storage.delete(doc.getStoredObjectKey());
        } catch (DocumentStorageException e) {
            log.warn("Failed to delete physical file for document {}", id);
            throw new DocumentStorageException(
                    "Failed to delete document file; metadata change was rolled back", e);
        }
    }

    private Document getOwned(UUID id, UUID userId) {
        return documentRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Document not found"));
    }

    private long maxBytes() {
        return properties.maxFileSize().toBytes();
    }

    private DocumentResponse toResponse(Document doc) {
        return DocumentResponse.builder()
                .id(doc.getId())
                .originalFilename(doc.getOriginalFilename())
                .contentType(doc.getContentType())
                .fileSize(doc.getFileSize())
                .category(doc.getCategory())
                .description(doc.getDescription())
                .createdAt(doc.getCreatedAt())
                .updatedAt(doc.getUpdatedAt())
                .build();
    }

    /**
     * Record holding document metadata and the resource for streaming download.
     */
    public record DocumentDownload(Document document, org.springframework.core.io.Resource resource) {}
}