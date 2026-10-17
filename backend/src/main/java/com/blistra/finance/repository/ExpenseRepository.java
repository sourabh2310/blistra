package com.blistra.finance.repository;

import com.blistra.finance.domain.Expense;
import com.blistra.finance.domain.ExpenseCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Expenses are visible to everyone involved: the payer and every user with a
 * share. Aggregates return {@code Object[]} rows to keep balance and spending
 * maths in the database.
 */
public interface ExpenseRepository extends JpaRepository<Expense, UUID> {
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Expense e where e.id=:id")
    java.util.Optional<Expense> lockForUpdate(@Param("id") UUID id);
    Page<Expense> findByGroupId(UUID groupId, Pageable pageable);

    /**
     * Expenses involving {@code userId}, optionally narrowed to ones that also
     * involve {@code friendId}, a date window, a category and a text query.
     */
    @Query(value = """
            select e from Expense e
             where (e.paidBy = :userId
                    or exists (select 1 from ExpenseShare s where s.expense = e and s.userId = :userId))
               and (:friendId is null or e.groupId is null)
               and (:friendId is null
                    or e.paidBy = :friendId
                    or exists (select 1 from ExpenseShare s2 where s2.expense = e and s2.userId = :friendId))
               and (cast(:from as date) is null or e.spentOn >= :from)
               and (cast(:to as date) is null or e.spentOn <= :to)
               and (:category is null or e.category = :category)
               and (:query is null or lower(e.description) like :query)
            """)
    Page<Expense> search(@Param("userId") UUID userId,
                         @Param("friendId") UUID friendId,
                         @Param("from") LocalDate from,
                         @Param("to") LocalDate to,
                         @Param("category") ExpenseCategory category,
                         @Param("query") String query,
                         Pageable pageable);

    /** [otherUserId, currency, amount]: what others owe {@code userId} on expenses they paid. */
    @Query("""
            select s.userId, e.currency, sum(s.amount) from ExpenseShare s join s.expense e
             where e.paidBy = :userId and s.userId <> :userId and e.groupId is null
             group by s.userId, e.currency
            """)
    List<Object[]> owedToUser(@Param("userId") UUID userId);

    /** [payerId, currency, amount]: what {@code userId} owes others on expenses they paid. */
    @Query("""
            select e.paidBy, e.currency, sum(s.amount) from ExpenseShare s join s.expense e
             where s.userId = :userId and e.paidBy <> :userId and e.groupId is null
             group by e.paidBy, e.currency
            """)
    List<Object[]> owedByUser(@Param("userId") UUID userId);

    /** [currency, category, amount]: {@code userId}'s own share of spending. */
    @Query("""
            select e.currency, e.category, sum(s.amount) from ExpenseShare s join s.expense e
             where s.userId = :userId and e.spentOn between :from and :to
             group by e.currency, e.category
            """)
    List<Object[]> spendingByCategory(@Param("userId") UUID userId,
                                      @Param("from") LocalDate from,
                                      @Param("to") LocalDate to);

    /** [currency, date, amount]: {@code userId}'s own share of spending per day. */
    @Query("""
            select e.currency, e.spentOn, sum(s.amount) from ExpenseShare s join s.expense e
             where s.userId = :userId and e.spentOn between :from and :to
             group by e.currency, e.spentOn
            """)
    List<Object[]> spendingByDay(@Param("userId") UUID userId,
                                 @Param("from") LocalDate from,
                                 @Param("to") LocalDate to);

    /** [currency, amount]: what {@code userId} actually paid out. */
    @Query("""
            select e.currency, sum(e.amount) from Expense e
             where e.paidBy = :userId and e.spentOn between :from and :to
             group by e.currency
            """)
    List<Object[]> paidByUser(@Param("userId") UUID userId,
                              @Param("from") LocalDate from,
                              @Param("to") LocalDate to);
}
