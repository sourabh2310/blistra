package com.blistra.documents.repository;

import com.blistra.documents.domain.Document;
import com.blistra.documents.domain.DocumentCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DocumentRepository extends JpaRepository<Document, UUID> {

    Optional<Document> findByIdAndUserId(UUID id, UUID userId);

    @Query("""
        SELECT d FROM Document d
        WHERE d.user.id = :userId
          AND (:category IS NULL OR d.category = :category)
          AND (:from IS NULL OR d.createdAt >= :from)
          AND (:to IS NULL OR d.createdAt <= :to)
        ORDER BY d.createdAt DESC
    """)
    Page<Document> searchOwned(
            @Param("userId") UUID userId,
            @Param("category") DocumentCategory category,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to,
            Pageable pageable
    );
}