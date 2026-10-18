package com.blistra.finance.controller;

import com.blistra.finance.application.*;
import com.blistra.finance.dto.*;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.users.application.CurrentUserProvider;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@RestController
@RequestMapping("/api/v1/finance/groups")
public class FinanceGroupController {
    private final FinanceGroupService groups;
    private final ExpenseService expenses;
    private final ExpenseRepository repository;
    private final CurrentUserProvider current;
    @org.springframework.beans.factory.annotation.Autowired
    private FinanceGroupExportService export;
    public FinanceGroupController(FinanceGroupService groups, ExpenseService expenses,
            ExpenseRepository repository, CurrentUserProvider current) {
        this.groups=groups; this.expenses=expenses; this.repository=repository; this.current=current;
    }
    public record Create(@NotBlank @Size(max=120) String name, @Pattern(regexp="[A-Z]{3}") @NotNull String currency) {}
    public record Invite(@NotBlank @Size(max=30) String username) {}
    public record Transfer(@NotNull UUID userId) {}
    public record Archive(boolean archived) {}
    @GetMapping public List<FinanceGroupService.Group> list() { return groups.list(); }
    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public FinanceGroupService.Group create(@Valid @RequestBody Create body) { return groups.create(body.name(),body.currency()); }
    @GetMapping("/{id}") public FinanceGroupService.Detail detail(@PathVariable UUID id) { return groups.detail(id); }
    @PostMapping("/{id}/members") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void invite(@PathVariable UUID id,@Valid @RequestBody Invite body) { groups.invite(id,body.username()); }
    @PostMapping("/{id}/accept") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@PathVariable UUID id) { groups.accept(id); }
    @DeleteMapping("/{id}/membership") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable UUID id) { groups.leave(id); }
    @PostMapping("/{id}/owner") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void transfer(@PathVariable UUID id,@Valid @RequestBody Transfer body) { groups.transfer(id,body.userId()); }
    @PostMapping("/{id}/archive") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void archive(@PathVariable UUID id,@RequestBody Archive body) { groups.archive(id,body.archived()); }
    @GetMapping("/{id}/export")
    public org.springframework.http.ResponseEntity<Map<String,Object>> export(@PathVariable UUID id) {
        return org.springframework.http.ResponseEntity.ok().cacheControl(org.springframework.http.CacheControl.noStore())
            .header("Content-Disposition","attachment; filename=\"blistra-trip-"+id+".json\"")
            .body(export.export(id));
    }
    @GetMapping("/{id}/expenses") @Transactional(readOnly=true)
    public PageResponse<ExpenseResponse> expenses(@PathVariable UUID id,
            @RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="50") int size) {
        UUID me=current.getCurrentUser().getId(); groups.requireMember(id,me);
        var result=repository.findByGroupId(id, PageRequest.of(Math.max(0,page),Math.min(100,Math.max(1,size)),Sort.by(Sort.Direction.DESC,"spentOn")));
        return new PageResponse<>(expenses.toResponses(result.getContent(),me),result.getNumber(),result.getSize(),result.getTotalElements(),result.getTotalPages(),result.isLast());
    }
}
