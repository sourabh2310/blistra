package com.blistra.documents.application;

import com.blistra.common.exception.InvalidRequestException;
import com.blistra.documents.config.DocumentsProperties;
import com.blistra.documents.support.AllowedDocumentType;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.util.unit.DataSize;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DocumentValidatorTest {

    @Mock
    private DocumentsProperties properties;

    @Test
    void validateAndDetect_validPdf() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "report.pdf", "application/pdf",
                new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34}); // %PDF-1.4

        String mime = validator.validateAndDetect(file);

        assertThat(mime).isEqualTo("application/pdf");
    }

    @Test
    void validateAndDetect_validJpeg() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg",
                new byte[]{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46}); // JPEG header

        String mime = validator.validateAndDetect(file);

        assertThat(mime).isEqualTo("image/jpeg");
    }

    @Test
    void validateAndDetect_validPng() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "image.png", "image/png",
                new byte[]{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00}); // PNG header

        String mime = validator.validateAndDetect(file);

        assertThat(mime).isEqualTo("image/png");
    }

    @Test
    void validateAndDetect_nullFileThrows() {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);

        assertThatThrownBy(() -> validator.validateAndDetect(null))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("A file is required");
    }

    @Test
    void validateAndDetect_emptyFileThrows() {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile("file", "empty.pdf", "application/pdf", new byte[0]);

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("A file is required");
    }

    @Test
    void validateAndDetect_unsupportedExtensionThrows() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "document.txt", "text/plain", "content".getBytes());

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("Unsupported file type");
    }

    @Test
    void validateAndDetect_oversizedDeclaredSizeThrows() {
        when(properties.maxFileSize()).thenReturn(DataSize.ofKilobytes(1));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "big.pdf", "application/pdf", new byte[2048]);

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("exceeds maximum allowed size");
    }

    @Test
    void validateAndDetect_disallowedContentTypeThrows() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "evil.pdf", "text/html", // declared as HTML but extension is .pdf
                new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34});

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("not allowed for this file extension");
    }

    @Test
    void validateAndDetect_octetStreamAllowed() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "report.pdf", "application/octet-stream",
                new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34});

        String mime = validator.validateAndDetect(file);

        assertThat(mime).isEqualTo("application/pdf");
    }

    @Test
    void validateAndDetect_extensionMismatchThrows() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        // File named .pdf but content is JPEG
        MockMultipartFile file = new MockMultipartFile(
                "file", "photo.pdf", "application/pdf",
                new byte[]{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46});

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("does not match actual content type");
    }

    @Test
    void validateAndDetect_corruptedContentThrows() throws IOException {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        MockMultipartFile file = new MockMultipartFile(
                "file", "corrupt.pdf", "application/pdf", "not a pdf".getBytes());

        assertThatThrownBy(() -> validator.validateAndDetect(file))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("not a supported document type");
    }

    @Test
    void validateMetadata_longDescriptionThrows() {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);
        String longDesc = "a".repeat(1001);

        assertThatThrownBy(() -> validator.validateMetadata(longDesc))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("at most 1000 characters");
    }

    @Test
    void validateMetadata_validDescriptionPasses() {
        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));

        DocumentValidator validator = new DocumentValidator(properties);

        validator.validateMetadata("Valid description");
        validator.validateMetadata("");
        validator.validateMetadata(null);
        validator.validateMetadata("a".repeat(1000));
    }
}