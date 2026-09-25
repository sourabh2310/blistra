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

    @Query(value = """
        SELECT * FROM documents d
        WHERE d.user_id = :userId
          AND (CAST(:category AS text) IS NULL OR d.category = :category)
          AND (CAST(:from AS timestamp) IS NULL OR d.created_at >= :from)
          AND (CAST(:to AS timestamp) IS NULL OR d.created_at <= :to)
        ORDER BY d.created_at DESC
    """, nativeQuery = true)
    Page<Document> searchOwned(
            @Param("userId") UUID userId,
            @Param("category") String category,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to,
            Pageable pageable
    );
}