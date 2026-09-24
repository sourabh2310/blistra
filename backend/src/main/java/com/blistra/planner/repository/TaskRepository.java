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
    @Query(value = """
            SELECT t.* FROM planner_task t
            WHERE t.user_id = :userId
              AND t.status IN (:statuses)
              AND (CAST(:listId AS uuid) IS NULL OR t.list_id = :listId)
              AND (CAST(:priority AS text) IS NULL OR t.priority = :priority)
               AND (CAST(:from AS timestamptz) IS NULL OR
                    ((t.due_at IS NOT NULL AND t.due_at >= :from) OR
                     (t.start_at IS NOT NULL AND t.start_at >= :from)))
               AND (CAST(:to AS timestamptz) IS NULL OR
                    ((t.due_at IS NOT NULL AND t.due_at < :to) OR
                     (t.start_at IS NOT NULL AND t.start_at < :to)))
              AND (CAST(:overdueCutoff AS timestamptz) IS NULL OR (t.due_at IS NOT NULL AND
                    (t.due_at < :todayStart OR (t.due_time IS NOT NULL AND t.due_at < :overdueCutoff))))
            ORDER BY
              CASE WHEN :sortByCompletion THEN t.completed_at END DESC NULLS LAST,
              t.due_at ASC NULLS LAST,
              t.created_at DESC
            """, nativeQuery = true)
    Page<Task> search(@Param("userId") UUID userId,
                      @Param("statuses") Collection<String> statuses,
                      @Param("listId") UUID listId,
                      @Param("priority") String priority,
                      @Param("from") OffsetDateTime from,
                      @Param("to") OffsetDateTime to,
                      @Param("overdueCutoff") OffsetDateTime overdueCutoff,
                      @Param("todayStart") OffsetDateTime todayStart,
                      @Param("sortByCompletion") boolean sortByCompletion,
                      Pageable pageable);

    @EntityGraph(attributePaths = {"list"})
    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND t.status IN :activeStatuses
              AND ((t.dueAt IS NOT NULL AND t.dueAt >= :todayStart AND t.dueAt < :tomorrowStart)
                OR (t.startAt IS NOT NULL AND t.startAt >= :todayStart AND t.startAt < :tomorrowStart))
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
              AND ((t.dueAt IS NOT NULL AND t.dueAt >= :startInclusive AND t.dueAt < :endExclusive)
                OR (t.startAt IS NOT NULL AND t.startAt >= :startInclusive AND t.startAt < :endExclusive))
            ORDER BY t.dueAt ASC
            """)
    java.util.List<Task> findDueInRange(@Param("userId") UUID userId,
                                        @Param("activeStatuses") Collection<TaskStatus> activeStatuses,
                                        @Param("startInclusive") OffsetDateTime startInclusive,
                                        @Param("endExclusive") OffsetDateTime endExclusive);

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

    @Query("""
            SELECT t FROM Task t
            WHERE t.user.id = :userId
              AND t.status = com.blistra.planner.domain.TaskStatus.COMPLETED
              AND t.completedAt >= :startInclusive
              AND t.completedAt < :endExclusive
            """)
    java.util.List<Task> findCompletedInRange(@Param("userId") UUID userId,
                                              @Param("startInclusive") OffsetDateTime startInclusive,
                                              @Param("endExclusive") OffsetDateTime endExclusive);

    @Query("""
            SELECT COUNT(DISTINCT t) FROM Task t
            WHERE t.user.id = :userId
              AND t.status <> com.blistra.planner.domain.TaskStatus.CANCELLED
              AND ((t.dueAt >= :startInclusive AND t.dueAt < :endExclusive)
                OR (t.startAt >= :startInclusive AND t.startAt < :endExclusive))
            """)
    long countDistinctDueOrScheduledInRange(@Param("userId") UUID userId,
                                            @Param("startInclusive") OffsetDateTime startInclusive,
                                            @Param("endExclusive") OffsetDateTime endExclusive);

    @Query("""
            SELECT COUNT(DISTINCT t) FROM Task t
            WHERE t.user.id = :userId
              AND t.status = com.blistra.planner.domain.TaskStatus.COMPLETED
              AND ((t.dueAt >= :startInclusive AND t.dueAt < :endExclusive)
                OR (t.startAt >= :startInclusive AND t.startAt < :endExclusive))
            """)
    long countCompletedDueOrScheduledInRange(@Param("userId") UUID userId,
                                            @Param("startInclusive") OffsetDateTime startInclusive,
                                            @Param("endExclusive") OffsetDateTime endExclusive);

    @Modifying
    @Query("UPDATE Task t SET t.list = null WHERE t.user.id = :userId AND t.list.id = :listId")
    void detachList(@Param("userId") UUID userId, @Param("listId") UUID listId);

    }
