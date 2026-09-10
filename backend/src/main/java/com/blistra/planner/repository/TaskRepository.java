package com.blistra.planner.repository;

import com.blistra.planner.domain.Task;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TaskRepository extends JpaRepository<Task, UUID> {

    Optional<Task> findByIdAndUserId(UUID id, UUID userId);

    long countByUserIdAndListId(UUID userId, UUID listId);

    /**
     * Ownership-aware search. Every Planner query is scoped to the owning user;
     * the owning user is always derived from the trusted security context.
     *
     * <p>Overdue semantics: a task is overdue when its due instant precedes the
     * start of the current day (in the user timezone), or, when it has an
     * explicit due time, when that instant precedes "now". An all-day task is
     * not considered overdue until its calendar day has passed.</p>
     */
    @EntityGraph(attributePaths = {"list"})
    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND t.status IN :statuses
              AND (:listId IS NULL OR t.list.id = :listId)
              AND (:priority IS NULL OR t.priority = :priority)
              AND (:from IS NULL OR (t.dueAt IS NOT NULL AND t.dueAt >= :from))
              AND (:to IS NULL OR (t.dueAt IS NOT NULL AND t.dueAt < :to))
              AND (:overdueCutoff IS NULL OR (t.dueAt IS NOT NULL AND
                    (t.dueAt < :todayStart OR (t.dueTime IS NOT NULL AND t.dueAt < :overdueCutoff))))
            """)
    Page<Task> search(@Param("userId") UUID userId,
                      @Param("statuses") Collection<TaskStatus> statuses,
                      @Param("listId") UUID listId,
                      @Param("priority") TaskPriority priority,
                      @Param("from") OffsetDateTime from,
                      @Param("to") OffsetDateTime to,
                      @Param("overdueCutoff") OffsetDateTime overdueCutoff,
                      @Param("todayStart") OffsetDateTime todayStart,
                      Pageable pageable);

    @EntityGraph(attributePaths = {"list"})
    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND t.status IN :activeStatuses
              AND t.dueAt IS NOT NULL AND t.dueAt >= :todayStart AND t.dueAt < :tomorrowStart
            """)
    java.util.List<Task> findDueToday(@Param("userId") UUID userId,
                                      @Param("activeStatuses") Collection<TaskStatus> activeStatuses,
                                      @Param("todayStart") OffsetDateTime todayStart,
                                      @Param("tomorrowStart") OffsetDateTime tomorrowStart);

    @EntityGraph(attributePaths = {"list"})
    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND t.status IN :activeStatuses
              AND t.dueAt IS NOT NULL
              AND (t.dueAt < :todayStart OR (t.dueTime IS NOT NULL AND t.dueAt < :now))
            """)
    java.util.List<Task> findOverdue(@Param("userId") UUID userId,
                                     @Param("activeStatuses") Collection<TaskStatus> activeStatuses,
                                     @Param("todayStart") OffsetDateTime todayStart,
                                     @Param("now") OffsetDateTime now);

    @Modifying
    @Query("UPDATE Task t SET t.list = null WHERE t.user.id = :userId AND t.list.id = :listId")
    void detachList(@Param("userId") UUID userId, @Param("listId") UUID listId);

    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND (LOWER(t.title) LIKE LOWER(:term) OR LOWER(t.description) LIKE LOWER(:term))
            """)
    Page<Task> searchByText(@Param("userId") UUID userId,
                            @Param("term") String term,
                            Pageable pageable);
}