package com.blistra.finance.controller;

import com.blistra.finance.application.FinanceOverviewService;
import com.blistra.finance.dto.BudgetRequest;
import com.blistra.finance.dto.BudgetResponse;
import com.blistra.finance.dto.FinanceOverviewResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.YearMonth;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/finance")
@Tag(name = "Finance Overview", description = "Monthly spending tracker and budgets")
public class FinanceOverviewController {

    private final FinanceOverviewService overviewService;

    public FinanceOverviewController(FinanceOverviewService overviewService) {
        this.overviewService = overviewService;
    }

    @GetMapping("/overview")
    @Operation(summary = "Spending for a month (yyyy-MM, default current) and balances with friends")
    public FinanceOverviewResponse overview(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth month) {
        return overviewService.overview(month);
    }

    @GetMapping("/budgets")
    @Operation(summary = "Monthly budgets with this month's spending")
    public List<BudgetResponse> budgets() {
        return overviewService.budgets();
    }

    @PutMapping("/budgets")
    @Operation(summary = "Set the monthly budget for a category (or overall) in a currency")
    public BudgetResponse saveBudget(@Valid @RequestBody BudgetRequest request) {
        return overviewService.saveBudget(request);
    }

    @DeleteMapping("/budgets/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove a budget")
    public void deleteBudget(@PathVariable UUID id) {
        overviewService.deleteBudget(id);
    }
}
