package com.blistra.finance.dto;

import java.util.List;

public record FriendsResponse(
        UserSummary me,
        List<FriendResponse> friends,
        List<FriendRequestResponse> incoming,
        List<FriendRequestResponse> outgoing
) {
}
