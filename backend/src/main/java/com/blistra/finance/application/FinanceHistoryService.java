package com.blistra.finance.application;

import com.blistra.finance.domain.*;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.util.*;

/** Append-only application history; excludes descriptions and private notes. */
@Service
public class FinanceHistoryService {
    private final JdbcTemplate jdbc;
    private final CurrentUserProvider current;
    private final FinanceGroupService groups;
    private final tools.jackson.databind.json.JsonMapper json;
    public FinanceHistoryService(JdbcTemplate jdbc, CurrentUserProvider current,FinanceGroupService groups,
            tools.jackson.databind.json.JsonMapper json) {
        this.jdbc=jdbc; this.current=current; this.groups=groups;
        this.json=json;
    }
    public Set<UUID> audience(Expense e) {
        var ids=new HashSet<UUID>(); ids.add(e.getCreatedBy()); ids.add(e.getPaidBy());
        e.getShares().forEach(s -> ids.add(s.getUserId())); return ids;
    }
    public Map<String,Object> snapshot(Expense e) {
        var state=new LinkedHashMap<String,Object>();
        state.put("amount",Money.toPlainString(e.getAmount())); state.put("currency",e.getCurrency());
        state.put("paidBy",e.getPaidBy()); state.put("spentOn",e.getSpentOn().toString());
        state.put("splitType",e.getSplitType().name()); state.put("category",e.getCategory().name());
        state.put("shares",e.getShares().stream().sorted(Comparator.comparing(s -> s.getUserId().toString()))
            .map(s -> { var share=new LinkedHashMap<String,Object>(); share.put("userId",s.getUserId());
                share.put("amount",Money.toPlainString(s.getAmount()));
                share.put("inputValue",s.getInputValue()==null ? null:s.getInputValue().toPlainString()); return share; }).toList());
        return state;
    }
    private Map<String,Object> snapshot(Settlement s) {
        return Map.of("amount",Money.toPlainString(s.getAmount()),"currency",s.getCurrency(),
            "payerId",s.getPayerId(),"payeeId",s.getPayeeId(),"settledOn",s.getSettledOn().toString(),"status",s.getStatus());
    }
    public void expense(Expense e,String action,UUID actor,Map<String,Object> before,Set<UUID> previous) {
        var ids=audience(e); ids.addAll(previous);
        append(e.getId(),"EXPENSE",action,actor,e.getGroupId(),ids,before,
                "DELETED".equals(action) ? null:snapshot(e),e.getCurrency());
    }
    public void settlement(Settlement s,String action,UUID actor) {
        Map<String,Object> before=null, after=snapshot(s);
        if ("DELETED".equals(action)) { before=after; after=null; }
        else if (Set.of("CONFIRMED","REJECTED").contains(action)) {
            before=new LinkedHashMap<>(after); before.put("status","PENDING");
        }
        append(s.getId(),"SETTLEMENT",action,actor,s.getGroupId(),Set.of(s.getPayerId(),s.getPayeeId()),
                before,after,s.getCurrency());
    }
    private void append(UUID id,String type,String action,UUID actor,UUID group,Set<UUID> people,
            Map<String,Object> before,Map<String,Object> after,String currency) {
        String audience="{"+people.stream().map(UUID::toString).sorted().collect(java.util.stream.Collectors.joining(","))+"}";
        jdbc.update("""
            INSERT INTO finance_change_history(entity_id,entity_type,action,actor_id,group_id,audience,before_amount,after_amount,currency,before_state,after_state)
            VALUES (?,?,?,?,?,CAST(? AS uuid[]),?,?,?,CAST(? AS jsonb),CAST(? AS jsonb))
            """,id,type,action,actor,group,audience,before==null?null:new BigDecimal(before.get("amount").toString()),
                after==null?null:new BigDecimal(after.get("amount").toString()),currency,
                before==null?null:json.writeValueAsString(before),after==null?null:json.writeValueAsString(after));
    }
    @Transactional(readOnly=true)
    public List<Map<String,Object>> list(UUID group,UUID friend) {
        return list(group,friend,0,100);
    }
    @Transactional(readOnly=true)
    public List<Map<String,Object>> list(UUID group,UUID friend,int page,int size) {
        UUID me=current.getCurrentUser().getId();
        if (group != null) groups.requireMember(group,me);
        return jdbc.queryForList("""
            SELECT id,entity_id AS "entityId",entity_type AS "entityType",action,actor_id AS "actorId",
              before_amount::text AS "beforeAmount",after_amount::text AS "afterAmount",currency,
              recorded_at AS "recordedAt",before_state::text AS "beforeState",after_state::text AS "afterState",
              COALESCE((SELECT p.display_name FROM user_profiles p WHERE p.user_id=actor_id),
                (SELECT u.username FROM users u WHERE u.id=actor_id),'Former participant') AS "actorName"
              FROM finance_change_history
            WHERE (? = ANY(audience) OR (CAST(? AS uuid) IS NOT NULL AND group_id=?))
              AND (CAST(? AS uuid) IS NULL OR group_id=?)
              AND (CAST(? AS uuid) IS NULL OR ? = ANY(audience))
              AND (CAST(? AS uuid) IS NULL OR group_id IS NULL)
            ORDER BY recorded_at DESC,id DESC LIMIT ? OFFSET ?
            """,me,group,group,group,group,friend,friend,friend,Math.min(100,Math.max(1,size)),
                (long)Math.max(0,page)*Math.min(100,Math.max(1,size)));
    }
}
