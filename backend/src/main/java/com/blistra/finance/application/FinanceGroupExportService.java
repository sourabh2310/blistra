package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;

/** A consistent, bounded ledger export. No tokens, email addresses or phone numbers. */
@Service
public class FinanceGroupExportService {
    private final FinanceGroupService groups;
    private final FinanceHistoryService history;
    private final ExpenseRepository expenses;
    private final ExpenseService expenseService;
    private final SettlementService paymentService;
    private final CurrentUserProvider current;
    private final JdbcTemplate jdbc;

    public FinanceGroupExportService(FinanceGroupService groups,FinanceHistoryService history,
            ExpenseRepository expenses,ExpenseService expenseService,
            SettlementService paymentService,CurrentUserProvider current,JdbcTemplate jdbc) {
        this.groups=groups; this.history=history; this.expenses=expenses; this.expenseService=expenseService;
        this.paymentService=paymentService; this.current=current; this.jdbc=jdbc;
    }

    @Transactional(readOnly=true,isolation=Isolation.REPEATABLE_READ)
    public Map<String,Object> export(UUID id) {
        UUID me=current.getCurrentUser().getId(); groups.requireMember(id,me);
        Long count=jdbc.queryForObject("""
            SELECT (SELECT count(*) FROM finance_expenses WHERE group_id=?)
             + (SELECT count(*) FROM finance_settlements WHERE group_id=?)
             + (SELECT count(*) FROM finance_change_history WHERE group_id=?)
            """,Long.class,id,id,id);
        if (count!=null && count>1000) throw new BadRequestException(
            "This trip exceeds the 1,000-record download limit. Use the paginated ledger and history APIs for a larger export.");
        var historyRows=new ArrayList<Map<String,Object>>();
        for (int page=0; ;page++) {
            var batch=history.list(id,null,page,100); historyRows.addAll(batch);
            if (batch.size()<100) break;
        }
        var paymentRows=new ArrayList<com.blistra.finance.dto.SettlementResponse>();
        for (int page=0; ;page++) {
            var batch=paymentService.groupList(id,page,200); paymentRows.addAll(batch);
            if (batch.size()<200) break;
        }
        var expenseRows=expenses.findByGroupId(id,PageRequest.of(0,1000,Sort.by("createdAt").and(Sort.by("id"))));
        return Map.of("formatVersion",1,"exportedAt",Instant.now().toString(),"trip",groups.detail(id),
            "expenses",expenseService.toResponses(expenseRows.getContent(),me),"payments",paymentRows,"history",historyRows);
    }
}
