package com.blistra.finance.repository;

import com.blistra.finance.domain.FinanceTransaction;
import com.blistra.finance.domain.TransactionType;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Ownership-aware query builders for transactions. Every query is always
 * scoped to the authenticated user; the user id is never supplied by the
 * client.
 */
public final class FinanceTransactionSpecifications {

    private FinanceTransactionSpecifications() {
    }

    public static Specification<FinanceTransaction> filters(UUID userId, UUID accountId, UUID categoryId,
                                                            TransactionType type, LocalDate from, LocalDate to,
                                                            BigDecimal amountMin, BigDecimal amountMax) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("user").get("id"), userId));
            if (accountId != null) {
                predicates.add(cb.equal(root.get("account").get("id"), accountId));
            }
            if (categoryId != null) {
                predicates.add(cb.equal(root.get("category").get("id"), categoryId));
            }
            if (type != null) {
                predicates.add(cb.equal(root.get("type"), type));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("occurredAt"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("occurredAt"), to));
            }
            if (amountMin != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("amount"), amountMin));
            }
            if (amountMax != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("amount"), amountMax));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}