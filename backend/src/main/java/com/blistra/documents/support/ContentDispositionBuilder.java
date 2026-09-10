package com.blistra.documents.support;

import java.nio.charset.StandardCharsets;

/**
 * Builds RFC 5987 compatible Content-Disposition headers for safe filename handling.
 * Uses both 'filename' (fallback) and 'filename*' (UTF-8 encoded) parameters.
 */
public final class ContentDispositionBuilder {

    private ContentDispositionBuilder() {}

    private static final String UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

    /**
     * Builds a Content-Disposition header value with both fallback and RFC 5987 encoding.
     *
     * @param filename the original filename (already sanitized by FilenameSanitizer)
     * @param dispositionType "attachment" or "inline"
     * @return the header value
     */
    public static String build(String filename, String dispositionType) {
        if (filename == null || filename.isBlank()) {
            filename = "document";
        }

        // Fallback: ASCII-only, quoted, with dangerous chars escaped
        String fallback = asciiFallback(filename);

        // RFC 5987 encoding: UTF-8 percent-encoded
        String encoded = rfc5987Encode(filename);

        return dispositionType + "; filename=\"" + fallback + "\"; filename*=UTF-8''" + encoded;
    }

    public static String attachment(String filename) {
        return build(filename, "attachment");
    }

    public static String inline(String filename) {
        return build(filename, "inline");
    }

    private static String asciiFallback(String filename) {
        StringBuilder sb = new StringBuilder();
        for (char c : filename.toCharArray()) {
            if (c >= 32 && c < 127 && c != '"' && c != '\\') {
                sb.append(c);
            } else {
                sb.append('_');
            }
        }
        String result = sb.toString();
        return result.isEmpty() ? "document" : result;
    }

    private static String rfc5987Encode(String filename) {
        byte[] bytes = filename.getBytes(StandardCharsets.UTF_8);
        StringBuilder sb = new StringBuilder(bytes.length * 3);
        for (byte b : bytes) {
            char c = (char) (b & 0xFF);
            if (UNRESERVED.indexOf(c) >= 0) {
                sb.append(c);
            } else {
                sb.append('%');
                sb.append(Character.forDigit((c >> 4) & 0xF, 16));
                sb.append(Character.forDigit(c & 0xF, 16));
            }
        }
        return sb.toString().toUpperCase();
    }
}