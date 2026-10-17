package com.blistra.finance.dto;

import java.time.LocalDateTime;
import java.util.UUID;

public record FriendRequestResponse(UUID id, UserSummary user, LocalDateTime createdAt) {
}
