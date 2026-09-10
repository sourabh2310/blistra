package com.blistra.documents.repository;

import com.blistra.AbstractIntegrationTest;
import com.blistra.documents.domain.Document;
import com.blistra.documents.domain.DocumentCategory;
import com.blistra.users.domain.User;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class DocumentRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    private DocumentRepository documentRepository;

    @Autowired
    private UserRepository userRepository;

    private User user;
    private UUID userId;

    @BeforeEach
    void setUp() {
        documentRepository.deleteAll();
        deleteAllUsers();

        user = new User("test@example.com", "hash");
        user = userRepository.save(user);
        userId = user.getId();
    }

    @Test
    void saveAndRetrieve() {
        Document doc = new Document(user, "report.pdf", "key1",
                "application/pdf", 1024L, "hash123", DocumentCategory.MEDICAL, "Test");
        Document saved = documentRepository.save(doc);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getUser().getId()).isEqualTo(userId);
        assertThat(saved.getOriginalFilename()).isEqualTo("report.pdf");
        assertThat(saved.getCategory()).isEqualTo(DocumentCategory.MEDICAL);
    }

    @Test
    void findByIdAndUserId_success() {
        Document doc = new Document(user, "report.pdf", "key1",
                "application/pdf", 1024L, "hash123", DocumentCategory.MEDICAL, "Test");
        Document saved = documentRepository.save(doc);

        Optional<Document> found = documentRepository.findByIdAndUserId(saved.getId(), userId);

        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(saved.getId());
    }

    @Test
    void findByIdAndUserId_notFoundWrongUser() {
        Document doc = new Document(user, "report.pdf", "key1",
                "application/pdf", 1024L, "hash123", DocumentCategory.MEDICAL, "Test");
        Document saved = documentRepository.save(doc);

        UUID otherUserId = UUID.randomUUID();
        Optional<Document> found = documentRepository.findByIdAndUserId(saved.getId(), otherUserId);

        assertThat(found).isEmpty();
    }

    @Test
    void findByIdAndUserId_notFoundWrongId() {
        Optional<Document> found = documentRepository.findByIdAndUserId(UUID.randomUUID(), userId);

        assertThat(found).isEmpty();
    }

    @Test
    void searchOwned_noFilters() {
        Document d1 = new Document(user, "a.pdf", "k1", "application/pdf", 100L, "h1", DocumentCategory.MEDICAL, "d1");
        Document d2 = new Document(user, "b.jpg", "k2", "image/jpeg", 200L, "h2", DocumentCategory.FINANCE, "d2");
        documentRepository.saveAll(List.of(d1, d2));

        var page = documentRepository.searchOwned(userId, null, null, null, org.springframework.data.domain.PageRequest.of(0, 10));

        assertThat(page.getTotalElements()).isEqualTo(2);
        assertThat(page.getContent()).hasSize(2);
        // Ordered by createdAt DESC
        assertThat(page.getContent().get(0).getCreatedAt()).isAfterOrEqualTo(page.getContent().get(1).getCreatedAt());
    }

    @Test
    void searchOwned_filterByCategory() {
        Document d1 = new Document(user, "a.pdf", "k1", "application/pdf", 100L, "h1", DocumentCategory.MEDICAL, "d1");
        Document d2 = new Document(user, "b.jpg", "k2", "image/jpeg", 200L, "h2", DocumentCategory.FINANCE, "d2");
        documentRepository.saveAll(List.of(d1, d2));

        var page = documentRepository.searchOwned(userId, DocumentCategory.MEDICAL.name(), null, null, org.springframework.data.domain.PageRequest.of(0, 10));

        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getCategory()).isEqualTo(DocumentCategory.MEDICAL);
    }

    @Test
    void searchOwned_filterByDateRange() {
        Document d1 = new Document(user, "old.pdf", "k1", "application/pdf", 100L, "h1", DocumentCategory.MEDICAL, "old");
        Document d2 = new Document(user, "new.jpg", "k2", "image/jpeg", 200L, "h2", DocumentCategory.FINANCE, "new");
        documentRepository.saveAll(List.of(d1, d2));

        jdbcTemplate.update("UPDATE documents SET created_at = ? WHERE id = ?",
                LocalDateTime.now().minusDays(10), d1.getId());
        jdbcTemplate.update("UPDATE documents SET created_at = ? WHERE id = ?",
                LocalDateTime.now().minusDays(1), d2.getId());

        var page = documentRepository.searchOwned(userId, null,
                LocalDateTime.now().minusDays(5), null,
                org.springframework.data.domain.PageRequest.of(0, 10));

        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getOriginalFilename()).isEqualTo("new.jpg");
    }

    @Test
    void searchOwned_otherUserNotIncluded() {
        User other = new User("other@example.com", "hash");
        other = userRepository.save(other);

        Document d1 = new Document(user, "a.pdf", "k1", "application/pdf", 100L, "h1", DocumentCategory.MEDICAL, "d1");
        Document d2 = new Document(other, "b.pdf", "k2", "application/pdf", 200L, "h2", DocumentCategory.MEDICAL, "d2");
        documentRepository.saveAll(List.of(d1, d2));

        var page = documentRepository.searchOwned(userId, null, null, null, org.springframework.data.domain.PageRequest.of(0, 10));

        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getUser().getId()).isEqualTo(userId);
    }
}