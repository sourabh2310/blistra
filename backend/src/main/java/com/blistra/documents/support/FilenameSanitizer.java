package com.blistra.documents.support;

/**
 * Sanitizes untrusted original filenames for safe storage as metadata
 * and for use in Content-Disposition headers.
 */
public final class FilenameSanitizer {

    private FilenameSanitizer() {}

    /**
     * Returns a safe version of the original filename.
     * - Strips path components (both / and \)
     * - Removes control characters
     * - Truncates to 255 characters
     * - Returns "document" if result is empty
     */
    public static String sanitize(String original) {
        if (original == null || original.isBlank()) {
            return "document";
        }

        // Normalize path separators and extract base name
        String name = original.replace('\\', '/');
        int idx = name.lastIndexOf('/');
        String base = idx >= 0 ? name.substring(idx + 1) : name;

        // Remove control characters
        base = base.replaceAll("[\\p{Cntrl}]", "");

        // Trim whitespace
        base = base.strip();

        if (base.isEmpty()) {
            return "document";
        }

        // Truncate to database column length (255)
        if (base.length() > 255) {
            base = base.substring(0, 255);
        }

        return base;
    }
}