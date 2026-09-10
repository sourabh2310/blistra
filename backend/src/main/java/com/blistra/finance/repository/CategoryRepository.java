package com.blistra.finance.repository;

import com.blistra.finance.domain.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CategoryRepository extends JpaRepository<Category, UUID> {

    Optional<Category> findByIdAndUserId(UUID id, UUID userId);

    List<Category> findAllByUserIdOrderByNameAsc(UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);
}