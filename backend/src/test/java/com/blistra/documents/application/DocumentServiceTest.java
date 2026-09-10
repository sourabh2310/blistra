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
import com.blistra.documents.storage.DocumentTooLargeException;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.util.unit.DataSize;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DocumentServiceTest {

    @Mock private DocumentRepository documentRepository;
    @Mock private DocumentStorageService storage;
    @Mock private DocumentValidator validator;
    @Mock private DocumentsProperties properties;
    @Mock private UserRepository userRepository;

    private DocumentService service;
    private User testUser;
    private UUID userId;
    private UUID docId;

    @BeforeEach
    void setUp() {
        service = new DocumentService(documentRepository, storage, validator, properties, userRepository);

        userId = UUID.randomUUID();
        testUser = new User("test@example.com", "hash");
        testUser.setId(userId);
        testUser.setStatus(UserStatus.ACTIVE);

        docId = UUID.randomUUID();

        when(properties.maxFileSize()).thenReturn(DataSize.ofMegabytes(10));
    }

    private void authenticate(User user) {
        UserDetails userDetails = new org.springframework.security.core.userdetails.User(
                user.getEmail(), user.getPasswordHash(), List.of());
        Authentication auth = new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    private void clearAuth() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void upload_success() throws IOException, NoSuchAlgorithmException {
        authenticate(testUser);

        MockMultipartFile file = new MockMultipartFile("file", "report.pdf", "application/pdf",
                new byte[]{0x25, 0x50, 0x44, 0x46}); // %PDF
        String objectKey = UUID.randomUUID().toString();
        String contentHash = "abc123";

        when(validator.validateAndDetect(file)).thenReturn("application/pdf");
        doAnswer(invocation -> {
            InputStream in = invocation.getArgument(0);
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] buf = new byte[8192];
            int n;
            long total = 0;
            while ((n = in.read(buf)) != -1) {
                md.update(buf, 0, n);
                total += n;
            }
            // Store hash for verification
            contentHash = java.util.HexFormat.of().formatHex(md.digest());
            return total;
        }).when(storage).store(anyString(), any(), anyLong());

        Document savedDoc = new Document(testUser, "report.pdf", objectKey,
                "application/pdf", 4L, contentHash, DocumentCategory.MEDICAL, "Test");
        savedDoc.setId(docId);
        when(documentRepository.save(any(Document.class))).thenReturn(savedDoc);

        DocumentResponse response = service.upload(file, DocumentCategory.MEDICAL, "Test");

        assertThat(response.getId()).isEqualTo(docId);
        assertThat(response.getOriginalFilename()).isEqualTo("report.pdf");
        assertThat(response.getContentType()).isEqualTo("application/pdf");
        assertThat(response.getFileSize()).isEqualTo(4L);
        assertThat(response.getContentHash()).isNull(); // not exposed in response
        assertThat(response.getCategory()).isEqualTo(DocumentCategory.MEDICAL);
        assertThat(response.getDescription()).isEqualTo("Test");

        verify(storage).store(anyString(), any(), eq(10_485_760L));
        verify(documentRepository).save(any(Document.class));
    }

    @Test
    void upload_storageTooLarge_throwsAndCleansUp() throws IOException {
        authenticate(testUser);

        MockMultipartFile file = new MockMultipartFile("file", "big.pdf", "application/pdf", new byte[100]);
        when(validator.validateAndDetect(file)).thenReturn("application/pdf");
        when(storage.store(anyString(), any(), anyLong()))
                .thenThrow(new DocumentTooLargeException("too large"));

        assertThatThrownBy(() -> service.upload(file, DocumentCategory.OTHER, null))
                .isInstanceOf(InvalidRequestException.class)
                .hasMessageContaining("exceeds");

        verify(storage, never()).delete(anyString()); // handled by storage
    }

    @Test
    void upload_persistenceFailure_cleansUpOrphan() throws IOException {
        authenticate(testUser);

        MockMultipartFile file = new MockMultipartFile("file", "report.pdf", "application/pdf",
                new byte[]{0x25, 0x50, 0x44, 0x46});
        String objectKey = UUID.randomUUID().toString();

        when(validator.validateAndDetect(file)).thenReturn("application/pdf");
        when(storage.store(anyString(), any(), anyLong())).thenReturn(4L);
        when(documentRepository.save(any(Document.class))).thenThrow(new RuntimeException("DB down"));

        assertThatThrownBy(() -> service.upload(file, DocumentCategory.MEDICAL, null))
                .isInstanceOf(RuntimeException.class);

        verify(storage).delete(objectKey);
    }

    @Test
    void upload_unauthenticated_throws() {
        clearAuth();
        MockMultipartFile file = new MockMultipartFile("file", "report.pdf", "application/pdf", new byte[4]);

        assertThatThrownBy(() -> service.upload(file, DocumentCategory.OTHER, null))
                .isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    void list_returnsPagedResults() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(UUID.randomUUID());

        Page<Document> page = new PageImpl<>(List.of(doc), PageRequest.of(0, 20), 1);
        when(documentRepository.searchOwned(eq(userId), isNull(), isNull(), isNull(), any()))
                .thenReturn(page);

        DocumentPageResponse response = service.list(null, null, null, 0, 20);

        assertThat(response.getContent()).hasSize(1);
        assertThat(response.getTotalElements()).isEqualTo(1);
        assertThat(response.getPage()).isEqualTo(0);
        assertThat(response.getSize()).isEqualTo(20);
    }

    @Test
    void get_ownedDocumentReturns() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));

        DocumentResponse response = service.get(docId);

        assertThat(response.getId()).isEqualTo(docId);
        assertThat(response.getOriginalFilename()).isEqualTo("a.pdf");
    }

    @Test
    void get_unownedDocumentThrowsNotFound() {
        authenticate(testUser);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(docId))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Document not found");
    }

    @Test
    void download_returnsResource() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));
        when(storage.load("key1")).thenReturn(mock(org.springframework.core.io.Resource.class));

        var download = service.download(docId);

        assertThat(download.document()).isEqualTo(doc);
        assertThat(download.resource()).isNotNull();
    }

    @Test
    void update_changesCategory() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "old desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));
        when(documentRepository.save(doc)).thenReturn(doc);

        DocumentUpdateRequest request = new DocumentUpdateRequest();
        request.setCategory(DocumentCategory.FINANCE);

        DocumentResponse response = service.update(docId, request);

        assertThat(response.getCategory()).isEqualTo(DocumentCategory.FINANCE);
        assertThat(doc.getCategory()).isEqualTo(DocumentCategory.FINANCE);
    }

    @Test
    void update_clearsDescriptionWhenBlank() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "old desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));
        when(documentRepository.save(doc)).thenReturn(doc);

        DocumentUpdateRequest request = new DocumentUpdateRequest();
        request.setDescription("   ");

        DocumentResponse response = service.update(docId, request);

        assertThat(doc.getDescription()).isNull();
    }

    @Test
    void update_noChangesReturnsSame() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));

        DocumentUpdateRequest request = new DocumentUpdateRequest();

        DocumentResponse response = service.update(docId, request);

        verify(documentRepository, never()).save(any());
        assertThat(response.getDescription()).isEqualTo("desc");
    }

    @Test
    void delete_removesMetadataAndFile() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));

        service.delete(docId);

        verify(documentRepository).delete(doc);
        verify(storage).delete("key1");
    }

    @Test
    void delete_storageFailure_throwsButMetadataAlreadyDeleted() {
        authenticate(testUser);

        Document doc = new Document(testUser, "a.pdf", "key1", "application/pdf", 100L,
                "hash1", DocumentCategory.MEDICAL, "desc");
        doc.setId(docId);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.of(doc));
        doThrow(new DocumentStorageException("disk error")).when(storage).delete("key1");

        assertThatThrownBy(() -> service.delete(docId))
                .isInstanceOf(DocumentStorageException.class);

        verify(documentRepository).delete(doc); // metadata deleted first
    }

    @Test
    void getOwned_notFound_throwsNotFound() {
        authenticate(testUser);

        when(documentRepository.findByIdAndUserId(docId, userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> {
            // Access private method via reflection or test through public
            service.get(docId);
        }).isInstanceOf(ResourceNotFoundException.class);
    }
}