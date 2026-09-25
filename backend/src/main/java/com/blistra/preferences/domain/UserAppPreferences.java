package com.blistra.preferences.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Per-user Home/bottom-navigation customization. Owned by the authenticated
 * user; the client never supplies the owning user id. The user id is a plain
 * foreign-key value (no entity association needed).
 */
@Entity
@Table(name = "user_app_preferences")
@Getter
@Setter
@NoArgsConstructor
public class UserAppPreferences {

    @Id
    @Column(name = "user_id", columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "bottom_nav", nullable = false, columnDefinition = "TEXT")
    private String bottomNav;

    @Column(name = "home_widgets", nullable = false, columnDefinition = "TEXT")
    private String homeWidgets;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public UserAppPreferences(UUID userId, String bottomNav, String homeWidgets) {
        this.userId = userId;
        this.bottomNav = bottomNav;
        this.homeWidgets = homeWidgets;
        this.updatedAt = LocalDateTime.now();
    }
}
