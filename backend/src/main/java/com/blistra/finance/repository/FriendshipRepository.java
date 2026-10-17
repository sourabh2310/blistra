package com.blistra.finance.repository;

import com.blistra.finance.domain.Friendship;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FriendshipRepository extends JpaRepository<Friendship, UUID> {

    @Query("select f from Friendship f where f.requesterId = :userId or f.addresseeId = :userId")
    List<Friendship> findAllInvolving(@Param("userId") UUID userId);

    @Query("""
            select f from Friendship f
             where (f.requesterId = :a and f.addresseeId = :b)
                or (f.requesterId = :b and f.addresseeId = :a)
            """)
    Optional<Friendship> findBetween(@Param("a") UUID a, @Param("b") UUID b);
}
