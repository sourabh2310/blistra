package com.blistra.documents.support;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class AllowedDocumentTypeTest {

    @Test
    void allTypesHaveExtensionsAndMimeTypes() {
        for (AllowedDocumentType type : AllowedDocumentType.values()) {
            assertThat(type.getExtensions()).isNotEmpty();
            assertThat(type.getMimeTypes()).isNotEmpty();
            assertThat(type.getMagicBytes()).isNotEmpty();
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"pdf", "PDF", "Pdf"})
    void fromExtension_pdfCaseInsensitive(String ext) {
        assertThat(AllowedDocumentType.fromExtension(ext)).isEqualTo(AllowedDocumentType.PDF);
    }

    @ParameterizedTest
    @ValueSource(strings = {"jpg", "jpeg", "JPG", "JPEG"})
    void fromExtension_jpegCaseInsensitive(String ext) {
        assertThat(AllowedDocumentType.fromExtension(ext)).isEqualTo(AllowedDocumentType.JPEG);
    }

    @ParameterizedTest
    @ValueSource(strings = {"png", "PNG"})
    void fromExtension_pngCaseInsensitive(String ext) {
        assertThat(AllowedDocumentType.fromExtension(ext)).isEqualTo(AllowedDocumentType.PNG);
    }

    @Test
    void fromExtension_unknownReturnsNull() {
        assertThat(AllowedDocumentType.fromExtension("txt")).isNull();
        assertThat(AllowedDocumentType.fromExtension("exe")).isNull();
        assertThat(AllowedDocumentType.fromExtension("doc")).isNull();
        assertThat(AllowedDocumentType.fromExtension("")).isNull();
        assertThat(AllowedDocumentType.fromExtension(null)).isNull();
    }

    @Test
    void match_pdfMagicBytes() {
        byte[] pdfHeader = {0x25, 0x50, 0x44, 0x46, 0x2D}; // %PDF-
        assertThat(AllowedDocumentType.match(pdfHeader)).isEqualTo(AllowedDocumentType.PDF);
    }

    @Test
    void match_jpegMagicBytes() {
        byte[] jpegHeader = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0}; // FF D8 FF E0
        assertThat(AllowedDocumentType.match(jpegHeader)).isEqualTo(AllowedDocumentType.JPEG);
    }

    @Test
    void match_pngMagicBytes() {
        byte[] pngHeader = {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
        assertThat(AllowedDocumentType.match(pngHeader)).isEqualTo(AllowedDocumentType.PNG);
    }

    @Test
    void match_insufficientBytesReturnsNull() {
        byte[] shortHeader = {0x25, 0x50}; // only 2 bytes of PDF
        assertThat(AllowedDocumentType.match(shortHeader)).isNull();
    }

    @Test
    void match_unknownBytesReturnsNull() {
        byte[] unknown = {0x00, 0x01, 0x02, 0x03};
        assertThat(AllowedDocumentType.match(unknown)).isNull();
    }

    @Test
    void allExtensions_containsExpected() {
        List<String> all = AllowedDocumentType.allExtensions();
        assertThat(all).containsExactlyInAnyOrder("pdf", "jpg", "jpeg", "png");
    }

    @Test
    void allMimeTypes_containsExpected() {
        List<String> all = AllowedDocumentType.allMimeTypes();
        assertThat(all).contains("application/pdf", "image/jpeg", "image/png");
    }

    @Test
    void primaryMimeTypes_correct() {
        assertThat(AllowedDocumentType.PDF.getPrimaryMimeType()).isEqualTo("application/pdf");
        assertThat(AllowedDocumentType.JPEG.getPrimaryMimeType()).isEqualTo("image/jpeg");
        assertThat(AllowedDocumentType.PNG.getPrimaryMimeType()).isEqualTo("image/png");
    }
}