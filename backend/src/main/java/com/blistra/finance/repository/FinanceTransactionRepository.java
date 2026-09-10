package com.blistra.finance.repository;

import com.blistra.finance.domain.FinanceTransaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FinanceTransactionRepository extends JpaRepository<FinanceTransaction, UUID>,
        JpaSpecificationExecutor<FinanceTransaction> {

    Optional<FinanceTransaction> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);

    long countByUserIdAndCategoryId(UUID userId, UUID categoryId);

    Page<FinanceTransaction> findAllByUserIdOrderByOccurredAtDescCreatedAtDesc(UUID userId, Pageable pageable);

    /**
     * Sum of transaction amounts grouped by (account id, type) for a user.
     * Used to derive account balances from history.
     */
    @Query("SELECT t.account.id, t.type, SUM(t.amount) FROM FinanceTransaction t "
            + "WHERE t.user.id = :userId GROUP BY t.account.id, t.type")
    List<Object[]> sumByAccountAndType(@Param("userId") UUID userId);

    @Query("SELECT t.type, SUM(t.amount) FROM FinanceTransaction t "
            + "WHERE t.user.id = :userId AND t.account.id = :accountId GROUP BY t.type")
    List<Object[]> sumByTypeForAccount(@Param("userId") UUID userId,
                                       @Param("accountId") UUID accountId);

    /**
     * Sum of transaction amounts grouped by (currency, type) for a user within
     * a calendar-day range. Used to build currency-aware summaries.
     */
    @Query("SELECT t.currency, t.type, SUM(t.amount) FROM FinanceTransaction t "
            + "WHERE t.user.id = :userId AND t.occurredAt BETWEEN :from AND :to "
            + "GROUP BY t.currency, t.type")
    List<Object[]> sumByCurrencyAndType(@Param("userId") UUID userId,
                                        @Param("from") java.time.LocalDate from,
                                        @Param("to") java.time.LocalDate to);

    /**
     * Sum of expense amounts grouped by (currency, category) for a user within
     * a calendar-day range. Used to build per-currency spending-by-category.
     */
    @Query("SELECT t.currency, c.id, c.name, SUM(t.amount) FROM FinanceTransaction t "
            + "JOIN t.category c "
            + "WHERE t.user.id = :userId AND t.type = :type AND t.occurredAt BETWEEN :from AND :to "
            + "GROUP BY t.currency, c.id, c.name")
    List<Object[]> sumByCurrencyAndCategory(@Param("userId") UUID userId,
                                            @Param("type") com.blistra.finance.domain.TransactionType type,
                                            @Param("from") java.time.LocalDate from,
                                            @Param("to") java.time.LocalDate to);
}