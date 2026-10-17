package com.blistra.finance.repository;

import com.blistra.finance.domain.Settlement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface SettlementRepository extends JpaRepository<Settlement, UUID> {
    org.springframework.data.domain.Page<Settlement> findByGroupIdOrderByCreatedAtDesc(UUID groupId,
            org.springframework.data.domain.Pageable pageable);
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from Settlement s where s.id = :id")
    java.util.Optional<Settlement> lockForDecision(UUID id);

    @Query("""
            select s from Settlement s
             where s.groupId is null and (s.payerId = :userId or s.payeeId = :userId)
               and (:friendId is null or s.payerId = :friendId or s.payeeId = :friendId)
             order by s.settledOn desc, s.createdAt desc
            """)
    List<Settlement> findInvolving(@Param("userId") UUID userId, @Param("friendId") UUID friendId);

    /** [payeeId, currency, amount]: what {@code userId} has paid back to others. */
    @Query("""
            select s.payeeId, s.currency, sum(s.amount) from Settlement s
             where s.payerId = :userId and s.status in ('CONFIRMED','LEGACY_RECORDED') and s.groupId is null group by s.payeeId, s.currency
            """)
    List<Object[]> paidByUser(@Param("userId") UUID userId);

    /** [payerId, currency, amount]: what others have paid back to {@code userId}. */
    @Query("""
            select s.payerId, s.currency, sum(s.amount) from Settlement s
             where s.payeeId = :userId and s.status in ('CONFIRMED','LEGACY_RECORDED') and s.groupId is null group by s.payerId, s.currency
            """)
    List<Object[]> receivedByUser(@Param("userId") UUID userId);
}
