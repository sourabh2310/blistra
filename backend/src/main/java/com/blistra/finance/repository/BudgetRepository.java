package com.blistra.finance.repository;

import com.blistra.finance.domain.Budget;
import com.blistra.finance.domain.ExpenseCategory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BudgetRepository extends JpaRepository<Budget, UUID> {

    List<Budget> findByUserIdOrderByCurrencyAsc(UUID userId);

    Optional<Budget> findByIdAndUserId(UUID id, UUID userId);

    Optional<Budget> findByUserIdAndCategoryAndCurrency(UUID userId, ExpenseCategory category, String currency);

    Optional<Budget> findByUserIdAndCategoryIsNullAndCurrency(UUID userId, String currency);
}
