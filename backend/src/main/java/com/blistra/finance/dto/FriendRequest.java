package com.blistra.finance.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record FriendRequest(@NotBlank @Size(max = 50) String username) {
}
