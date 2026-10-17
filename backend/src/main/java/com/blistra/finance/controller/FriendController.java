package com.blistra.finance.controller;

import com.blistra.finance.application.FriendService;
import com.blistra.finance.application.SettlementService;
import com.blistra.finance.dto.FriendAddResult;
import com.blistra.finance.dto.FriendDetailResponse;
import com.blistra.finance.dto.FriendRequest;
import com.blistra.finance.dto.FriendsResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/finance/friends")
@Tag(name = "Finance Friends", description = "Find friends by username to split expenses with")
public class FriendController {

    private final FriendService friendService;
    private final SettlementService settlementService;

    public FriendController(FriendService friendService, SettlementService settlementService) {
        this.friendService = friendService;
        this.settlementService = settlementService;
    }

    @GetMapping
    @Operation(summary = "Friends with balances, plus incoming and outgoing requests")
    public FriendsResponse list() {
        return friendService.list();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Send a friend request by username",
            description = "If that user already sent you a request, this accepts it instead.")
    public FriendAddResult add(@Valid @RequestBody FriendRequest request) {
        return friendService.add(request.username());
    }

    @PostMapping("/requests/{requestId}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Accept an incoming friend request")
    public void accept(@PathVariable UUID requestId) {
        friendService.accept(requestId);
    }

    @DeleteMapping("/requests/{requestId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Decline an incoming request or cancel one you sent")
    public void dismiss(@PathVariable UUID requestId) {
        friendService.dismissRequest(requestId);
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Balance, shared expenses and repayments with one person")
    public FriendDetailResponse detail(@PathVariable UUID userId) {
        return settlementService.friendDetail(userId);
    }

    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove a friend", description = "Shared expenses and balances are kept.")
    public void remove(@PathVariable UUID userId) {
        friendService.remove(userId);
    }
}
