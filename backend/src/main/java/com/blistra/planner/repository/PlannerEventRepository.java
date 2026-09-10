package com.blistra.planner.repository;

import com.blistra.planner.domain.EventStatus;
import com.blistra.planner.domain.PlannerEvent;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PlannerEventRepository extends JpaRepository<PlannerEvent, UUID> {

    Optional<PlannerEvent> findByIdAndUserId(UUID id, UUID userId);

    Page<PlannerEvent> findByUserId(UUID userId, Pageable pageable);

    @Query("""
            SELECT e FROM PlannerEvent e
            WHERE e.user.id = :userId
              AND e.status <> :cancelled
              AND e.startAt < :endExclusive AND e.endAt > :startInclusive
            ORDER BY e.startAt ASC
            """)
    List<PlannerEvent> findOverlapping(@Param("userId") UUID userId,
                                       @Param("cancelled") EventStatus cancelled,
                                       @Param("startInclusive") OffsetDateTime startInclusive,
                                       @Param("endExclusive") OffsetDateTime endExclusive);

    @Query("""
            SELECT e FROM PlannerEvent e
            WHERE e.user.id = :userId
              AND (LOWER(e.title) LIKE LOWER(:term) OR LOWER(e.description) LIKE LOWER(:term) OR LOWER(e.location) LIKE LOWER(:term))
            """)
    Page<PlannerEvent> searchByText(@Param("userId") UUID userId,
                                    @Param("term") String term,
                                    Pageable pageable);
}