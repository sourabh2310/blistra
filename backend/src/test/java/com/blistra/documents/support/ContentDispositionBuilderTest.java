package com.blistra.documents.support;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ContentDispositionBuilderTest {

    @Test
    void attachment_simpleFilename() {
        String result = ContentDispositionBuilder.attachment("report.pdf");
        assertThat(result).startsWith("attachment; filename=\"report.pdf\"; filename*=UTF-8''");
    }

    @Test
    void attachment_filenameWithSpaces() {
        String result = ContentDispositionBuilder.attachment("My Document.pdf");
        assertThat(result).contains("filename=\"My Document.pdf\"");
        assertThat(result).contains("filename*=UTF-8''My%20Document.pdf");
    }

    @Test
    void attachment_filenameWithUnicode() {
        String result = ContentDispositionBuilder.attachment("документ.pdf");
        assertThat(result).contains("filename*=UTF-8''");
        // Verify percent-encoding of UTF-8 bytes
        assertThat(result).contains("%D0%B4%D0%BE%D0%BA%D1%83%D0%BC%D0%B5%D0%BD%D1%82.pdf");
    }

    @Test
    void attachment_nullFilenameDefaults() {
        String result = ContentDispositionBuilder.attachment(null);
        assertThat(result).contains("filename=\"document\"");
    }

    @Test
    void attachment_emptyFilenameDefaults() {
        String result = ContentDispositionBuilder.attachment("");
        assertThat(result).contains("filename=\"document\"");
    }

    @Test
    void attachment_escapesQuotesInFallback() {
        String result = ContentDispositionBuilder.attachment("test\"quote.pdf");
        assertThat(result).contains("filename=\"test_quote.pdf\"");
    }

    @Test
    void attachment_escapesBackslashInFallback() {
        String result = ContentDispositionBuilder.attachment("test\\path.pdf");
        assertThat(result).contains("filename=\"test_path.pdf\"");
    }

    @Test
    void inline_usesInlineDisposition() {
        String result = ContentDispositionBuilder.inline("image.png");
        assertThat(result).startsWith("inline; filename=\"image.png\"; filename*=UTF-8''");
    }

    @Test
    void rfc5987Encoding_usesUnreservedCharsDirectly() {
        String result = ContentDispositionBuilder.attachment("abc123-_.~.pdf");
        assertThat(result).contains("filename*=UTF-8''abc123-_.~.pdf");
    }
}