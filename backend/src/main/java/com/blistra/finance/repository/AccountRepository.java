package com.blistra.finance.repository;

import com.blistra.finance.domain.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AccountRepository extends JpaRepository<Account, UUID> {

    Optional<Account> findByIdAndUserId(UUID id, UUID userId);

    List<Account> findAllByUserIdOrderByCreatedAtAsc(UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);
}