package com.blistra.planner.repository;

import com.blistra.planner.domain.TaskList;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TaskListRepository extends JpaRepository<TaskList, UUID> {

    Optional<TaskList> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByUserIdAndName(UUID userId, String name);

    List<TaskList> findByUserIdOrderByCreatedAtAsc(UUID userId);

    @Query("""
            SELECT l FROM TaskList l
            WHERE l.user.id = :userId
              AND (LOWER(l.name) LIKE LOWER(:term) OR LOWER(l.description) LIKE LOWER(:term))
            """)
    Page<TaskList> searchByText(@Param("userId") UUID userId,
                                @Param("term") String term,
                                Pageable pageable);
}