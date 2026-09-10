package com.blistra.finance.repository;

import com.blistra.finance.domain.FinanceTransfer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FinanceTransferRepository extends JpaRepository<FinanceTransfer, UUID>,
        JpaSpecificationExecutor<FinanceTransfer> {

    Optional<FinanceTransfer> findByIdAndUserId(UUID id, UUID userId);

    /**
     * Sum of transfer amounts grouped by source account for a user.
     */
    @Query("SELECT t.sourceAccount.id, SUM(t.amount) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId GROUP BY t.sourceAccount.id")
    List<Object[]> sumBySourceAccount(@Param("userId") UUID userId);

    /**
     * Sum of transfer amounts grouped by destination account for a user.
     */
    @Query("SELECT t.destinationAccount.id, SUM(t.amount) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId GROUP BY t.destinationAccount.id")
    List<Object[]> sumByDestinationAccount(@Param("userId") UUID userId);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId AND t.sourceAccount.id = :accountId")
    java.math.BigDecimal sumOutForAccount(@Param("userId") UUID userId,
                                          @Param("accountId") UUID accountId);

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId AND t.destinationAccount.id = :accountId")
    java.math.BigDecimal sumInForAccount(@Param("userId") UUID userId,
                                         @Param("accountId") UUID accountId);

    /**
     * Sum of transfer amounts grouped by (source account currency, transferred_at)
     * for a user within a range. Used to report transfer totals per currency.
     */
    @Query("SELECT t.sourceAccount.currency, SUM(t.amount) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId AND t.transferredAt BETWEEN :from AND :to "
            + "GROUP BY t.sourceAccount.currency")
    List<Object[]> transferOutByCurrency(@Param("userId") UUID userId,
                                         @Param("from") java.time.LocalDate from,
                                         @Param("to") java.time.LocalDate to);

    /**
     * Sum of transfer amounts grouped by (destination account currency, transferred_at)
     * for a user within a range. Used to report transfer totals per currency.
     */
    @Query("SELECT t.destinationAccount.currency, SUM(t.amount) FROM FinanceTransfer t "
            + "WHERE t.user.id = :userId AND t.transferredAt BETWEEN :from AND :to "
            + "GROUP BY t.destinationAccount.currency")
    List<Object[]> transferInByCurrency(@Param("userId") UUID userId,
                                        @Param("from") java.time.LocalDate from,
                                        @Param("to") java.time.LocalDate to);
}