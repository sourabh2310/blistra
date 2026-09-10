package com.blistra.documents.application;

import com.blistra.common.exception.InvalidRequestException;
import com.blistra.documents.config.DocumentsProperties;
import com.blistra.documents.support.AllowedDocumentType;
import com.blistra.documents.support.FilenameSanitizer;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;

@Component
public class DocumentValidator {

    private final long maxBytes;

    public DocumentValidator(DocumentsProperties properties) {
        this.maxBytes = properties.maxFileSize().toBytes();
    }

    /**
     * Validates the uploaded file and returns the detected canonical MIME type.
     *
     * @param file the uploaded file
     * @return the canonical MIME type (e.g., "application/pdf")
     * @throws InvalidRequestException if validation fails
     */
    public String validateAndDetect(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new InvalidRequestException("A file is required");
        }

        String originalFilename = file.getOriginalFilename();
        String extension = extractExtension(originalFilename);

        // 1. Extension must be allowed
        AllowedDocumentType byExt = AllowedDocumentType.fromExtension(extension);
        if (byExt == null) {
            throw new InvalidRequestException(
                    "Unsupported file type. Allowed extensions: " + AllowedDocumentType.allExtensions());
        }

        // 2. Check declared size upfront (may be -1 if unknown)
        long declaredSize = file.getSize();
        if (declaredSize != -1 && declaredSize > maxBytes) {
            throw new InvalidRequestException(
                    "File exceeds maximum allowed size of " + formatBytes(maxBytes));
        }

        // 3. Check declared Content-Type header (if present and not octet-stream)
        String declaredContentType = file.getContentType();
        if (declaredContentType != null && !declaredContentType.isBlank()) {
            String normalized = declaredContentType.toLowerCase(Locale.ROOT);
            if (!normalized.equals(MediaType.APPLICATION_OCTET_STREAM_VALUE)) {
                boolean allowed = byExt.getMimeTypes().stream()
                        .anyMatch(m -> m.equalsIgnoreCase(normalized));
                if (!allowed) {
                    throw new InvalidRequestException(
                            "Declared content type is not allowed for this file extension: " + declaredContentType);
                }
            }
        }

        // 4. Read magic bytes from actual content (authoritative)
        AllowedDocumentType detected;
        try (InputStream is = file.getInputStream()) {
            byte[] header = new byte[8]; // enough for PNG (8 bytes)
            int totalRead = 0;
            while (totalRead < header.length) {
                int n = is.read(header, totalRead, header.length - totalRead);
                if (n == -1) {
                    break;
                }
                totalRead += n;
            }
            byte[] actualHeader = java.util.Arrays.copyOf(header, totalRead);
            detected = AllowedDocumentType.match(actualHeader);
        } catch (IOException e) {
            throw new InvalidRequestException("Failed to read uploaded file content", e);
        }

        if (detected == null) {
            throw new InvalidRequestException(
                    "File content is not a supported document type (PDF, JPEG, PNG)");
        }

        // 5. Extension must match detected type (prevents spoofing)
        if (detected != byExt) {
            throw new InvalidRequestException(
                    "File extension does not match actual content type. Expected: " + byExt.name()
                            + ", detected: " + detected.name());
        }

        return detected.getPrimaryMimeType();
    }

    /**
     * Validates metadata fields.
     */
    public void validateMetadata(String description) {
        if (description != null && description.length() > 1000) {
            throw new InvalidRequestException("Description must be at most 1000 characters");
        }
    }

    private String extractExtension(String filename) {
        if (filename == null || filename.isBlank()) {
            return "";
        }
        String base = FilenameSanitizer.sanitize(filename);
        int dotIdx = base.lastIndexOf('.');
        if (dotIdx <= 0 || dotIdx == base.length() - 1) {
            return "";
        }
        return base.substring(dotIdx + 1).toLowerCase(Locale.ROOT);
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) {
            return bytes + " B";
        } else if (bytes < 1024 * 1024) {
            return (bytes / 1024) + " KB";
        } else {
            return (bytes / (1024 * 1024)) + " MB";
        }
    }
}