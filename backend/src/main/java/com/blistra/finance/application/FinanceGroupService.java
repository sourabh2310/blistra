package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.dto.UserSummary;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.repository.UserRepository;
import com.blistra.users.repository.UserProfileRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

/** Invitation consent is the authorization boundary for trip expenses. */
@Service
@Transactional
public class FinanceGroupService {
    private final JdbcTemplate jdbc;
    private final CurrentUserProvider current;
    private final UserRepository users;
    private final UserProfileRepository profiles;
    private final FinanceUsers identities;
    public FinanceGroupService(JdbcTemplate jdbc, CurrentUserProvider current,
            UserRepository users, UserProfileRepository profiles, FinanceUsers identities) {
        this.jdbc = jdbc; this.current = current; this.users = users;
        this.profiles = profiles; this.identities = identities;
    }
    public record Group(UUID id, String name, String currency, UUID ownerId, String membership) {}
    public record Member(UserSummary user, String status, boolean owner) {}
    public record Balance(UUID userId, String currency, String amount) {}
    public record Detail(Group group, List<Member> members, List<Balance> balances) {}

    @Transactional(readOnly = true)
    public List<Group> list() {
        UUID me = current.getCurrentUser().getId();
        return jdbc.query("""
            SELECT g.*, m.status FROM finance_groups g JOIN finance_group_members m ON m.group_id=g.id
            WHERE m.user_id=? ORDER BY g.created_at DESC LIMIT 100
            """, (rs, n) -> new Group(rs.getObject("id", UUID.class), rs.getString("name"),
                rs.getString("currency"), rs.getObject("owner_id", UUID.class), rs.getString("status")), me);
    }

    public Group create(String name, String currency) {
        if (name == null || name.isBlank() || name.trim().length() > 120 || currency == null || !currency.matches("[A-Z]{3}"))
            throw new BadRequestException("Enter a group name and three-letter currency");
        UUID me = current.getCurrentUser().getId();
        users.lockById(me).orElseThrow();
        Integer count = jdbc.queryForObject("SELECT count(*) FROM finance_group_members WHERE user_id=?", Integer.class, me);
        if (count != null && count >= 100) throw new BadRequestException("Group limit reached");
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO finance_groups(id,owner_id,name,currency) VALUES (?,?,?,?)", id,me,name.trim(),currency);
        jdbc.update("INSERT INTO finance_group_members(group_id,user_id,status) VALUES (?,?,'ACCEPTED')",id,me);
        return new Group(id,name.trim(),currency,me,"ACCEPTED");
    }

    @Transactional(readOnly = true)
    public void requireMember(UUID group, UUID user) {
        Integer n = jdbc.queryForObject("SELECT count(*) FROM finance_group_members WHERE group_id=? AND user_id=? AND status='ACCEPTED'",Integer.class,group,user);
        if (n == null || n == 0) throw new ResourceNotFoundException("Group not found");
    }

    public Set<UUID> acceptedMemberIds(UUID group, UUID me) {
        // Serializes expense membership checks with invitation/leave changes.
        if (jdbc.queryForList("SELECT id FROM finance_groups WHERE id=? FOR UPDATE", UUID.class,group).isEmpty())
            throw new ResourceNotFoundException("Group not found");
        requireMember(group,me);
        return new HashSet<>(jdbc.queryForList("SELECT user_id FROM finance_group_members WHERE group_id=? AND status='ACCEPTED'",UUID.class,group));
    }

    public void invite(UUID group, String username) {
        UUID me = current.getCurrentUser().getId();
        requireMember(group,me);
        UUID owner = jdbc.queryForObject("SELECT owner_id FROM finance_groups WHERE id=? FOR UPDATE",UUID.class,group);
        if (!me.equals(owner)) throw new BadRequestException("Only the group owner can invite members");
        var other = users.findByUsernameIgnoreCase(username == null ? "" : username.trim().replaceFirst("^@", ""))
                .filter(u -> !u.isBlocked()).orElseThrow(() -> new ResourceNotFoundException("User not found"));
        if (!profiles.findByUserId(other.getId()).map(p -> p.isAllowFriendRequests()).orElse(true))
            throw new BadRequestException("This person is not accepting invitations");
        Integer count = jdbc.queryForObject("SELECT count(*) FROM finance_group_members WHERE group_id=?",Integer.class,group);
        if (count != null && count >= 100) throw new BadRequestException("A group may have at most 100 members");
        int added = jdbc.update("INSERT INTO finance_group_members(group_id,user_id,status) VALUES (?,?,'INVITED') ON CONFLICT DO NOTHING",group,other.getId());
        if (added == 0) throw new BadRequestException("This person is already a member or invited");
    }

    public void accept(UUID group) {
        UUID me = current.getCurrentUser().getId();
        if (jdbc.queryForList("SELECT id FROM finance_groups WHERE id=? FOR UPDATE",UUID.class,group).isEmpty())
            throw new ResourceNotFoundException("Invitation not found");
        int changed = jdbc.update("UPDATE finance_group_members SET status='ACCEPTED' WHERE group_id=? AND user_id=? AND status='INVITED'",group,me);
        if (changed == 0) throw new ResourceNotFoundException("Invitation not found");
    }

    public void transfer(UUID group, UUID nextOwner) {
        UUID me=current.getCurrentUser().getId();
        var members=acceptedMemberIds(group,me);
        UUID owner=jdbc.queryForObject("SELECT owner_id FROM finance_groups WHERE id=?",UUID.class,group);
        if (!me.equals(owner)) throw new BadRequestException("Only the owner can transfer ownership");
        if (!members.contains(nextOwner)) throw new BadRequestException("Choose an accepted member");
        jdbc.update("UPDATE finance_groups SET owner_id=? WHERE id=?",nextOwner,group);
    }

    public void leave(UUID group) {
        UUID me = current.getCurrentUser().getId();
        var owners = jdbc.queryForList("SELECT owner_id FROM finance_groups WHERE id=? FOR UPDATE",UUID.class,group);
        if (owners.isEmpty()) throw new ResourceNotFoundException("Group not found");
        if (me.equals(owners.get(0))) throw new BadRequestException("The group owner cannot leave before transferring ownership");
        if (jdbc.update("DELETE FROM finance_group_members WHERE group_id=? AND user_id=?",group,me) == 0)
            throw new ResourceNotFoundException("Group membership not found");
    }

    @Transactional(readOnly = true)
    public Detail detail(UUID id) {
        UUID me = current.getCurrentUser().getId();
        requireMember(id,me);
        Group group = jdbc.queryForObject("SELECT * FROM finance_groups WHERE id=?", (rs,n) ->
            new Group(id,rs.getString("name"),rs.getString("currency"),rs.getObject("owner_id",UUID.class),"ACCEPTED"),id);
        var rows = jdbc.queryForList("SELECT user_id,status FROM finance_group_members WHERE group_id=? ORDER BY joined_at",id);
        var summaries = identities.summaries(rows.stream().map(r -> (UUID)r.get("user_id")).toList());
        var members = rows.stream().map(r -> new Member(FinanceUsers.of(summaries,(UUID)r.get("user_id")),
            (String)r.get("status"),group.ownerId().equals(r.get("user_id")))).toList();
        var balances = jdbc.query("""
            SELECT user_id,currency,sum(amount) AS total FROM (
              SELECT paid_by AS user_id,currency,amount FROM finance_expenses WHERE group_id=?
              UNION ALL SELECT s.user_id,e.currency,-s.amount FROM finance_expense_shares s
                JOIN finance_expenses e ON e.id=s.expense_id WHERE e.group_id=?
              UNION ALL SELECT payer_id,currency,amount FROM finance_settlements WHERE group_id=? AND status IN ('CONFIRMED','LEGACY_RECORDED')
              UNION ALL SELECT payee_id,currency,-amount FROM finance_settlements WHERE group_id=? AND status IN ('CONFIRMED','LEGACY_RECORDED')
            ) entries GROUP BY user_id,currency HAVING sum(amount)<>0
            """,(rs,n) -> new Balance(rs.getObject("user_id",UUID.class),rs.getString("currency"),
                rs.getBigDecimal("total").setScale(4).toPlainString()),id,id,id,id);
        return new Detail(group,members,balances);
    }
}
