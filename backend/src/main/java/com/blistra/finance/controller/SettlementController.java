package com.blistra.finance.controller;

import com.blistra.finance.application.SettlementService;
import com.blistra.finance.dto.SettlementRequest;
import com.blistra.finance.dto.SettlementResponse;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/finance/settlements")
@Tag(name = "Finance Settlements", description = "Record repayments between friends")
public class SettlementController {

    private final SettlementService settlementService;

    public SettlementController(SettlementService settlementService) {
        this.settlementService = settlementService;
    }

    @GetMapping
    @Operation(summary = "Repayments you are part of, optionally with one friend")
    public List<SettlementResponse> list(@RequestParam(required = false) UUID friendId,
            @RequestParam(required = false) UUID groupId,
            @RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="200") int size) {
        return groupId == null ? settlementService.list(friendId) : settlementService.groupList(groupId,page,size);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Record a repayment (settle up)")
    public SettlementResponse create(@Valid @RequestBody SettlementRequest request) {
        return settlementService.create(request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a repayment you recorded")
    public void delete(@PathVariable UUID id) {
        settlementService.delete(id);
    }

    @PostMapping("/{id}/confirm")
    public SettlementResponse confirm(@PathVariable UUID id) {
        return settlementService.decide(id, true);
    }

    @PostMapping("/{id}/reject")
    public SettlementResponse reject(@PathVariable UUID id) {
        return settlementService.decide(id, false);
    }
}
