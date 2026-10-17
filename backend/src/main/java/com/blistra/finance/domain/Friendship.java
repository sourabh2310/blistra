package com.blistra.finance.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * A link between two users that allows them to split expenses. Created as
 * PENDING by the requester and becomes ACCEPTED once the addressee accepts.
 */
@Entity
@Table(name = "finance_friendships")
public class Friendship {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "requester_id", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID requesterId;

    @Column(name = "addressee_id", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID addresseeId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private FriendshipStatus status;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    protected Friendship() {
    }

    public Friendship(UUID requesterId, UUID addresseeId) {
        this.requesterId = requesterId;
        this.addresseeId = addresseeId;
        this.status = FriendshipStatus.PENDING;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public void accept() {
        this.status = FriendshipStatus.ACCEPTED;
    }

    public boolean isAccepted() {
        return status == FriendshipStatus.ACCEPTED;
    }

    /** The other side of the link, seen from {@code userId}. */
    public UUID otherUser(UUID userId) {
        return requesterId.equals(userId) ? addresseeId : requesterId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getRequesterId() {
        return requesterId;
    }

    public UUID getAddresseeId() {
        return addresseeId;
    }

    public FriendshipStatus getStatus() {
        return status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }
}
