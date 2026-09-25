package com.blistra.documents.support;

import org.springframework.http.MediaType;

import java.util.List;
import java.util.Locale;

/**
 * Centrally defined allowed document types with their signatures, extensions, and MIME types.
 * This is the single source of truth for file type validation.
 */
public enum AllowedDocumentType {
    PDF(
            List.of("pdf"),
            List.of(MediaType.APPLICATION_PDF_VALUE),
            new int[]{0x25, 0x50, 0x44, 0x46} // %PDF
    ),
    JPEG(
            List.of("jpg", "jpeg"),
            List.of(MediaType.IMAGE_JPEG_VALUE),
            new int[]{0xFF, 0xD8, 0xFF} // JPEG SOI + APP0
    ),
    PNG(
            List.of("png"),
            List.of(MediaType.IMAGE_PNG_VALUE),
            new int[]{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A} // PNG signature
    );

    private final List<String> extensions;
    private final List<String> mimeTypes;
    private final int[] magicBytes;

    AllowedDocumentType(List<String> extensions, List<String> mimeTypes, int[] magicBytes) {
        this.extensions = extensions;
        this.mimeTypes = mimeTypes;
        this.magicBytes = magicBytes;
    }

    public List<String> getExtensions() {
        return extensions;
    }

    public List<String> getMimeTypes() {
        return mimeTypes;
    }

    public int[] getMagicBytes() {
        return magicBytes;
    }

    public String getPrimaryMimeType() {
        return mimeTypes.get(0);
    }

    public static AllowedDocumentType fromExtension(String extension) {
        if (extension == null) {
            return null;
        }
        String ext = extension.toLowerCase(Locale.ROOT);
        for (AllowedDocumentType type : values()) {
            if (type.extensions.contains(ext)) {
                return type;
            }
        }
        return null;
    }

    public static AllowedDocumentType match(byte[] header) {
        for (AllowedDocumentType type : values()) {
            int[] magic = type.magicBytes;
            if (header.length >= magic.length) {
                boolean match = true;
                for (int i = 0; i < magic.length; i++) {
                    if ((header[i] & 0xFF) != magic[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    return type;
                }
            }
        }
        return null;
    }

    public static List<String> allExtensions() {
        return java.util.Arrays.stream(values())
                .flatMap(t -> t.extensions.stream())
                .toList();
    }

    public static List<String> allMimeTypes() {
        return java.util.Arrays.stream(values())
                .flatMap(t -> t.mimeTypes.stream())
                .toList();
    }
}