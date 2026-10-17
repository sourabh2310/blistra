package com.blistra.finance.application;

import com.blistra.auth.identity.IdentityNormalizer;
import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.domain.Friendship;
import com.blistra.finance.dto.FriendAddResult;
import com.blistra.finance.dto.FriendRequestResponse;
import com.blistra.finance.dto.FriendResponse;
import com.blistra.finance.dto.FriendsResponse;
import com.blistra.finance.dto.UserSummary;
import com.blistra.finance.repository.FriendshipRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Friends are found by exact username. A request must be accepted before
 * either side can add the other to an expense, so nobody can put costs on a
 * stranger's ledger.
 */
@Service
@Transactional(readOnly = true)
public class FriendService {

    private final FriendshipRepository friendshipRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FinanceUsers financeUsers;
    private final BalanceService balanceService;

    public FriendService(FriendshipRepository friendshipRepository,
                         UserRepository userRepository,
                         CurrentUserProvider currentUserProvider,
                         FinanceUsers financeUsers,
                         BalanceService balanceService) {
        this.friendshipRepository = friendshipRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
        this.financeUsers = financeUsers;
        this.balanceService = balanceService;
    }

    public FriendsResponse list() {
        UUID me = currentUserProvider.getCurrentUser().getId();
        List<Friendship> links = friendshipRepository.findAllInvolving(me);
        Map<UUID, Map<String, BigDecimal>> balances = balanceService.balances(me);

        Set<UUID> ids = new HashSet<>(balances.keySet());
        ids.add(me);
        links.forEach(link -> ids.add(link.otherUser(me)));
        Map<UUID, UserSummary> users = financeUsers.summaries(ids);

        List<FriendResponse> friends = new ArrayList<>();
        List<FriendRequestResponse> incoming = new ArrayList<>();
        List<FriendRequestResponse> outgoing = new ArrayList<>();
        Set<UUID> listed = new HashSet<>();
        for (Friendship link : links) {
            UUID other = link.otherUser(me);
            UserSummary user = FinanceUsers.of(users, other);
            if (link.isAccepted()) {
                friends.add(new FriendResponse(user, true, link.getUpdatedAt(),
                        BalanceService.toList(balances.get(other))));
                listed.add(other);
            } else if (link.getAddresseeId().equals(me)) {
                incoming.add(new FriendRequestResponse(link.getId(), user, link.getCreatedAt()));
            } else {
                outgoing.add(new FriendRequestResponse(link.getId(), user, link.getCreatedAt()));
            }
        }
        // Former friends with an open balance stay visible so it can be settled.
        for (Map.Entry<UUID, Map<String, BigDecimal>> entry : balances.entrySet()) {
            if (!listed.contains(entry.getKey())) {
                friends.add(new FriendResponse(FinanceUsers.of(users, entry.getKey()), false, null,
                        BalanceService.toList(entry.getValue())));
            }
        }
        friends.sort(Comparator.comparing((FriendResponse f) -> f.user().displayName().toLowerCase()));
        return new FriendsResponse(FinanceUsers.of(users, me), friends, incoming, outgoing);
    }

    @Transactional
    public FriendAddResult add(String rawUsername) {
        User me = currentUserProvider.getCurrentUser();
        String username = IdentityNormalizer.normalizeUsername(rawUsername == null ? null
                : rawUsername.trim().replaceFirst("^@", ""));
        if (username == null) {
            throw new BadRequestException("Enter a username");
        }
        User other = userRepository.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ResourceNotFoundException("No user with username @" + username));
        if (other.getId().equals(me.getId())) {
            throw new BadRequestException("You can't add yourself");
        }
        UserSummary summary = FinanceUsers.of(financeUsers.summaries(List.of(other.getId())), other.getId());
        var existing = friendshipRepository.findBetween(me.getId(), other.getId());
        if (existing.isPresent()) {
            Friendship link = existing.get();
            if (link.isAccepted()) {
                throw new ResourceAlreadyExistsException("@" + other.getUsername() + " is already your friend");
            }
            if (link.getRequesterId().equals(me.getId())) {
                throw new ResourceAlreadyExistsException("Request already sent to @" + other.getUsername());
            }
            // They already asked: adding them back accepts it.
            link.accept();
            return new FriendAddResult("ACCEPTED", summary);
        }
        friendshipRepository.save(new Friendship(me.getId(), other.getId()));
        return new FriendAddResult("PENDING", summary);
    }

    @Transactional
    public void accept(UUID requestId) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Friendship link = friendshipRepository.findById(requestId)
                .filter(l -> !l.isAccepted() && l.getAddresseeId().equals(me))
                .orElseThrow(() -> new ResourceNotFoundException("Friend request not found"));
        link.accept();
    }

    /** Declines an incoming request or cancels an outgoing one. */
    @Transactional
    public void dismissRequest(UUID requestId) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Friendship link = friendshipRepository.findById(requestId)
                .filter(l -> !l.isAccepted()
                        && (l.getAddresseeId().equals(me) || l.getRequesterId().equals(me)))
                .orElseThrow(() -> new ResourceNotFoundException("Friend request not found"));
        friendshipRepository.delete(link);
    }

    /** Unfriends; shared history and balances are kept. */
    @Transactional
    public void remove(UUID friendId) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        Friendship link = friendshipRepository.findBetween(me, friendId)
                .filter(Friendship::isAccepted)
                .orElseThrow(() -> new ResourceNotFoundException("Friend not found"));
        friendshipRepository.delete(link);
    }

    public Set<UUID> acceptedFriendIds(UUID userId) {
        return friendshipRepository.findAllInvolving(userId).stream()
                .filter(Friendship::isAccepted)
                .map(link -> link.otherUser(userId))
                .collect(Collectors.toSet());
    }

    public boolean areFriends(UUID a, UUID b) {
        return friendshipRepository.findBetween(a, b).map(Friendship::isAccepted).orElse(false);
    }

    public int pendingIncoming(UUID userId) {
        return (int) friendshipRepository.findAllInvolving(userId).stream()
                .filter(l -> !l.isAccepted() && l.getAddresseeId().equals(userId))
                .count();
    }
}
