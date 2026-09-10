package com.blistra.finance.repository;

import com.blistra.finance.domain.FinanceTransfer;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Ownership-aware query builders for transfers. Every query is always scoped
 * to the authenticated user; the user id is never supplied by the client.
 */
public final class FinanceTransferSpecifications {

    private FinanceTransferSpecifications() {
    }

    public static Specification<FinanceTransfer> filters(UUID userId, UUID sourceAccountId,
                                                         UUID destinationAccountId,
                                                         LocalDate from, LocalDate to) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("user").get("id"), userId));
            if (sourceAccountId != null) {
                predicates.add(cb.equal(root.get("sourceAccount").get("id"), sourceAccountId));
            }
            if (destinationAccountId != null) {
                predicates.add(cb.equal(root.get("destinationAccount").get("id"), destinationAccountId));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("transferredAt"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("transferredAt"), to));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }
}