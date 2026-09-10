package com.blistra.documents.controller;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.documents.domain.Document;
import com.blistra.documents.domain.DocumentCategory;
import com.blistra.documents.repository.DocumentRepository;
import com.blistra.users.repository.UserRepository;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class DocumentControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private DocumentRepository documentRepository;

    private static Path storageRoot;
    @TempDir
    static Path tempDir;

    static {
        try {
            storageRoot = Files.createTempDirectory("blistra-docs-test");
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @AfterAll
    static void cleanup() {
        try {
            Files.walk(storageRoot)
                    .sorted(java.util.Comparator.reverseOrder())
                    .forEach(p -> {
                        try { Files.deleteIfExists(p); } catch (Exception ignored) {}
                    });
        } catch (Exception ignored) {}
    }

    private void cleanStorage() throws java.io.IOException {
        if (Files.exists(storageRoot)) {
            try (java.util.stream.Stream<Path> walk = Files.walk(storageRoot)) {
                walk.sorted(java.util.Comparator.reverseOrder())
                        .filter(p -> !p.equals(storageRoot))
                        .forEach(p -> {
                            try { Files.deleteIfExists(p); } catch (Exception ignored) {}
                        });
            }
        }
    }

    @org.springframework.test.context.DynamicPropertySource
    static void overrideProps(org.springframework.test.context.DynamicPropertyRegistry registry) {
        registry.add("blistra.documents.storage-root", storageRoot::toString);
        registry.add("blistra.documents.max-file-size", () -> "1MB");
    }

    private static final String BASE_URL = "/api/v1/documents";
    private static final String REGISTER_URL = "/api/v1/auth/register";
    private static final String LOGIN_URL = "/api/v1/auth/login";

    private String userAToken;
    private String userBToken;
    private UUID userAId;
    private UUID userBId;

    @BeforeEach
    void setUp() throws Exception {
        documentRepository.deleteAll();
        deleteAllUsers();
        cleanStorage();

        // Register and login User A
        RegisterRequest regA = RegisterRequest.builder()
                .email("usera@example.com")
                .password("password123")
                .build();
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(regA)))
                .andExpect(status().isCreated());

        LoginRequest loginA = LoginRequest.builder()
                .email("usera@example.com")
                .password("password123")
                .build();
        MvcResult loginResultA = mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(loginA)))
                .andExpect(status().isOk())
                .andReturn();
        userAToken = jsonMapper.readTree(loginResultA.getResponse().getContentAsString()).get("token").asText();

        // Register and login User B
        RegisterRequest regB = RegisterRequest.builder()
                .email("userb@example.com")
                .password("password123")
                .build();
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(regB)))
                .andExpect(status().isCreated());

        LoginRequest loginB = LoginRequest.builder()
                .email("userb@example.com")
                .password("password123")
                .build();
        MvcResult loginResultB = mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(loginB)))
                .andExpect(status().isOk())
                .andReturn();
        userBToken = jsonMapper.readTree(loginResultB.getResponse().getContentAsString()).get("token").asText();

        // Get user IDs from DB for assertions
        userAId = userRepository.findByEmail("usera@example.com").orElseThrow().getId();
        userBId = userRepository.findByEmail("userb@example.com").orElseThrow().getId();
    }

    private MockMultipartFile createPdfFile(String name, byte[] content) {
        return new MockMultipartFile("file", name, "application/pdf", content);
    }

    private MockMultipartFile createJpegFile(String name, byte[] content) {
        return new MockMultipartFile("file", name, "image/jpeg", content);
    }

    private MockMultipartFile createPngFile(String name, byte[] content) {
        return new MockMultipartFile("file", name, "image/png", content);
    }

    private byte[] pdfBytes() {
        return new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34}; // %PDF-1.4
    }

    private byte[] jpegBytes() {
        return new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00}; // JPEG SOI + APP0
    }

    private byte[] pngBytes() {
        return new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D}; // PNG header
    }

    @Test
    void upload_pdfSuccess() throws Exception {
        MvcResult result = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .param("description", "Blood test results")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.originalFilename").value("report.pdf"))
                .andExpect(jsonPath("$.contentType").value("application/pdf"))
                .andExpect(jsonPath("$.category").value("MEDICAL"))
                .andExpect(jsonPath("$.description").value("Blood test results"))
                .andExpect(jsonPath("$.fileSize").value(8))
                .andExpect(jsonPath("$.createdAt").isNotEmpty())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        String docId = jsonMapper.readTree(responseBody).get("id").asText();

        // Verify physical file exists
        Document doc = documentRepository.findById(UUID.fromString(docId)).orElseThrow();
        assertThat(Files.exists(storageRoot.resolve(doc.getStoredObjectKey()))).isTrue();

        // Verify hash was computed
        String expectedHash = java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(pdfBytes()));
        assertThat(doc.getContentHash()).isEqualTo(expectedHash);
    }

    @Test
    void upload_jpegSuccess() throws Exception {
        mockMvc.perform(multipart(BASE_URL)
                        .file(createJpegFile("photo.jpg", jpegBytes()))
                        .param("category", "PERSONAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.contentType").value("image/jpeg"))
                .andExpect(jsonPath("$.category").value("PERSONAL"));
    }

    @Test
    void upload_pngSuccess() throws Exception {
        mockMvc.perform(multipart(BASE_URL)
                        .file(createPngFile("screenshot.png", pngBytes()))
                        .param("category", "REPORT")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.contentType").value("image/png"))
                .andExpect(jsonPath("$.category").value("REPORT"));
    }

    @Test
    void upload_unsupportedExtensionRejected() throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "document.txt", "text/plain", "text".getBytes());

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void upload_unsupportedContentTypeRejected() throws Exception {
        // File with .pdf extension but declared as text/html
        MockMultipartFile file = new MockMultipartFile("file", "evil.pdf", "text/html", pdfBytes());

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void upload_oversizedFileRejected() throws Exception {
        // 2MB file, limit is 1MB: declared-size check answers 413 before any
        // content inspection.
        byte[] large = new byte[2 * 1024 * 1024];
        MockMultipartFile file = new MockMultipartFile("file", "large.pdf", "application/pdf", large);

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value("FILE_TOO_LARGE"));
    }

    @Test
    void upload_missingFileRejected() throws Exception {
        mockMvc.perform(multipart(BASE_URL)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void upload_invalidMagicBytesRejected() throws Exception {
        // .pdf extension but not a PDF
        MockMultipartFile file = new MockMultipartFile("file", "fake.pdf", "application/pdf", "not a pdf".getBytes());

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void upload_extensionMismatchRejected() throws Exception {
        // .pdf extension but JPEG content
        MockMultipartFile file = new MockMultipartFile("file", "photo.pdf", "application/pdf", jpegBytes());

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void list_userAOnlySeesOwnDocuments() throws Exception {
        // User A uploads 2 docs
        mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("a1.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated());

        mockMvc.perform(multipart(BASE_URL)
                        .file(createJpegFile("a2.jpg", jpegBytes()))
                        .param("category", "PERSONAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated());

        // User B uploads 1 doc
        mockMvc.perform(multipart(BASE_URL)
                        .file(createPngFile("b1.png", pngBytes()))
                        .param("category", "REPORT")
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isCreated());

        // User A lists - should see only 2
        mockMvc.perform(get(BASE_URL)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content.length()").value(2));

        // User B lists - should see only 1
        mockMvc.perform(get(BASE_URL)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content.length()").value(1));
    }

    @Test
    void list_filterByCategory() throws Exception {
        mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("med.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated());

        mockMvc.perform(multipart(BASE_URL)
                        .file(createJpegFile("fin.jpg", jpegBytes()))
                        .param("category", "FINANCE")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated());

        mockMvc.perform(get(BASE_URL)
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].category").value("MEDICAL"));
    }

    @Test
    void list_pagination() throws Exception {
        for (int i = 0; i < 5; i++) {
            mockMvc.perform(multipart(BASE_URL)
                            .file(createPdfFile("doc" + i + ".pdf", pdfBytes()))
                            .param("category", "OTHER")
                            .header("Authorization", "Bearer " + userAToken))
                    .andExpect(status().isCreated());
        }

        mockMvc.perform(get(BASE_URL)
                        .param("page", "0")
                        .param("size", "2")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(2))
                .andExpect(jsonPath("$.totalElements").value(5))
                .andExpect(jsonPath("$.totalPages").value(3))
                .andExpect(jsonPath("$.content.length()").value(2));
    }

    @Test
    void get_ownedDocumentReturns() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(BASE_URL + "/" + docId)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(docId))
                .andExpect(jsonPath("$.originalFilename").value("report.pdf"))
                .andExpect(jsonPath("$.contentHash").doesNotExist()); // not exposed
    }

    @Test
    void get_unownedDocumentReturns404() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(BASE_URL + "/" + docId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
    }

    @Test
    void download_ownedDocumentStreamsContent() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(BASE_URL + "/" + docId + "/content")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "application/pdf"))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("report.pdf")))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("Cache-Control", "no-store"))
                .andExpect(content().bytes(pdfBytes()));
    }

    @Test
    void download_unownedDocumentReturns404() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(BASE_URL + "/" + docId + "/content")
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void update_changesCategoryAndDescription() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .param("description", "original")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        String updateJson = jsonMapper.writeValueAsString(
                new com.blistra.documents.dto.DocumentUpdateRequest(
                        DocumentCategory.FINANCE, "updated description"));

        mockMvc.perform(patch(BASE_URL + "/" + docId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateJson)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.category").value("FINANCE"))
                .andExpect(jsonPath("$.description").value("updated description"));
    }

    @Test
    void update_clearsDescriptionWhenBlank() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .param("description", "original")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        String updateJson = jsonMapper.writeValueAsString(
                new com.blistra.documents.dto.DocumentUpdateRequest(null, "   "));

        mockMvc.perform(patch(BASE_URL + "/" + docId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateJson)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.description").doesNotExist());
    }

    @Test
    void update_unownedDocumentReturns404() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        String updateJson = jsonMapper.writeValueAsString(
                new com.blistra.documents.dto.DocumentUpdateRequest(DocumentCategory.FINANCE, "new"));

        mockMvc.perform(patch(BASE_URL + "/" + docId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateJson)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void delete_ownedDocumentRemovesMetadataAndFile() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();
        Document doc = documentRepository.findById(UUID.fromString(docId)).orElseThrow();
        String objectKey = doc.getStoredObjectKey();
        assertThat(Files.exists(storageRoot.resolve(objectKey))).isTrue();

        mockMvc.perform(delete(BASE_URL + "/" + docId)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isNoContent());

        // Metadata gone
        assertThat(documentRepository.findById(UUID.fromString(docId))).isEmpty();
        // Physical file gone
        assertThat(Files.exists(storageRoot.resolve(objectKey))).isFalse();
    }

    @Test
    void delete_unownedDocumentReturns404() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(delete(BASE_URL + "/" + docId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void pathTraversal_filenameCannotControlStorage() throws Exception {
        // Try various path traversal filenames
        String[] malicious = {
                "../secret.txt",
                "..\\secret.txt",
                "../../outside.pdf",
                "C:\\Windows\\system32\\config\\sam",
                "/etc/passwd",
                "..%2F..%2Fetc%2Fpasswd",
                "..%5C..%5Cwindows%5Csystem32"
        };
        // Client names are sanitized to basenames before persisting as metadata.
        String[] sanitized = {
                "secret.txt",
                "secret.txt",
                "outside.pdf",
                "sam",
                "passwd",
                "..%2F..%2Fetc%2Fpasswd",
                "..%5C..%5Cwindows%5Csystem32"
        };

        for (int i = 0; i < malicious.length; i++) {
            MockMultipartFile file = new MockMultipartFile("file", malicious[i], "application/pdf", pdfBytes());

            MvcResult result = mockMvc.perform(multipart(BASE_URL)
                            .file(file)
                            .param("category", "OTHER")
                            .header("Authorization", "Bearer " + userAToken))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.originalFilename").value(sanitized[i]))
                    .andReturn();

            String stored = jsonMapper.readTree(result.getResponse().getContentAsString())
                    .get("originalFilename").asText();
            assertThat(stored).doesNotContain("/").doesNotContain("\\");
        }

        // Verify only one file per upload exists in storage (with UUID names)
        long fileCount = Files.walk(storageRoot)
                .filter(Files::isRegularFile)
                .count();
        assertThat(fileCount).isEqualTo(malicious.length);

        // Verify all stored files have UUID names (no path traversal)
        Files.walk(storageRoot)
                .filter(Files::isRegularFile)
                .forEach(path -> {
                    String fileName = path.getFileName().toString();
                    assertThat(fileName).matches("[0-9a-fA-F-]{36}");
                });
    }

    @Test
    void upload_missingOriginalFilenameDefaultsSafely() throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", null, "application/pdf", pdfBytes());

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.originalFilename").value("document"));
    }

    @Test
    void upload_oversizedValidFileReturns413() throws Exception {
        // Valid PDF magic but larger than the 1MB test limit: the declared-size
        // check must answer 413 FILE_TOO_LARGE (not 400).
        byte[] big = new byte[2 * 1024 * 1024];
        byte[] magic = pdfBytes();
        System.arraycopy(magic, 0, big, 0, magic.length);
        MockMultipartFile file = new MockMultipartFile("file", "big.pdf", "application/pdf", big);

        mockMvc.perform(multipart(BASE_URL)
                        .file(file)
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value("FILE_TOO_LARGE"));

        // No metadata persisted for the rejected upload.
        assertThat(documentRepository.count()).isZero();
    }

    @Test
    void download_traversalFilenameHasSafeDisposition() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("../../evil\".pdf", pdfBytes()))
                        .param("category", "OTHER")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();

        MvcResult download = mockMvc.perform(get(BASE_URL + "/" + docId + "/content")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("Cache-Control", "no-store"))
                .andReturn();

        String disposition = download.getResponse().getHeader("Content-Disposition");
        assertThat(disposition).startsWith("attachment;");
        assertThat(disposition).doesNotContain("../");
        assertThat(disposition).doesNotContain("\"evil\"");
    }

    @Test
    void delete_missingPhysicalFileStillSucceeds() throws Exception {
        MvcResult upload = mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated())
                .andReturn();

        String docId = jsonMapper.readTree(upload.getResponse().getContentAsString()).get("id").asText();
        Document doc = documentRepository.findById(UUID.fromString(docId)).orElseThrow();

        // Simulate an already-lost file: file deletion is idempotent.
        Files.deleteIfExists(storageRoot.resolve(doc.getStoredObjectKey()));

        mockMvc.perform(delete(BASE_URL + "/" + docId)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isNoContent());

        assertThat(documentRepository.findById(UUID.fromString(docId))).isEmpty();
    }

    @Test
    void unauthenticatedRequestsReturn401() throws Exception {
        mockMvc.perform(get(BASE_URL))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("test.pdf", pdfBytes()))
                        .param("category", "OTHER"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get(BASE_URL + "/some-uuid"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(delete(BASE_URL + "/some-uuid"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void list_responseDoesNotLeakInternalFields() throws Exception {
        mockMvc.perform(multipart(BASE_URL)
                        .file(createPdfFile("report.pdf", pdfBytes()))
                        .param("category", "MEDICAL")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isCreated());

        mockMvc.perform(get(BASE_URL)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].storedObjectKey").doesNotExist())
                .andExpect(jsonPath("$.content[0].contentHash").doesNotExist())
                .andExpect(jsonPath("$.content[0].userId").doesNotExist());
    }
}