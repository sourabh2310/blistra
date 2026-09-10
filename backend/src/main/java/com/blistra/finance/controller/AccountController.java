package com.blistra.finance.controller;

import com.blistra.finance.application.AccountService;
import com.blistra.finance.dto.AccountRequest;
import com.blistra.finance.dto.AccountResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/finance/accounts")
@Tag(name = "Finance Accounts", description = "Manage the user's financial accounts")
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    @GetMapping
    @Operation(summary = "List accounts", description = "Returns all accounts of the authenticated user with derived balances")
    public List<AccountResponse> list() {
        return accountService.list();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create an account")
    @ApiResponses(@ApiResponse(responseCode = "201", description = "Account created"))
    public AccountResponse create(@Valid @RequestBody AccountRequest request) {
        return accountService.create(request);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get an account")
    public AccountResponse get(@PathVariable UUID id) {
        return accountService.get(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update an account", description = "The currency of an account is immutable")
    public AccountResponse update(@PathVariable UUID id, @Valid @RequestBody AccountRequest request) {
        return accountService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Archive an account",
            description = "Archives the account. History is preserved but the account can no longer be used for new transactions or transfers.")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public ResponseEntity<Void> archive(@PathVariable UUID id) {
        accountService.archive(id);
        return ResponseEntity.noContent().build();
    }
}