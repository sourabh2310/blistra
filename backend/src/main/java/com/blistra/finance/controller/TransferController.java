package com.blistra.finance.controller;

import com.blistra.finance.application.TransferService;
import com.blistra.finance.dto.PageResponse;
import com.blistra.finance.dto.TransferRequest;
import com.blistra.finance.dto.TransferResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/finance/transfers")
@Tag(name = "Finance Transfers", description = "Move money between the user's own accounts")
public class TransferController {

    private final TransferService transferService;

    public TransferController(TransferService transferService) {
        this.transferService = transferService;
    }

    @GetMapping
    @Operation(summary = "List transfers",
            description = "Filtered, paginated listing of transfers between the user's accounts. "
                    + "Sorting is transferredAt descending then createdAt descending.")
    public PageResponse<TransferResponse> list(
            @RequestParam(required = false) UUID sourceAccountId,
            @RequestParam(required = false) UUID destinationAccountId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @Parameter(description = "Page index (zero based)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size (max 100)") @RequestParam(defaultValue = "20") int size) {
        return transferService.list(sourceAccountId, destinationAccountId, from, to, page, size);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a transfer",
            description = "Both accounts must belong to the same user and share a currency.")
    public TransferResponse create(@Valid @RequestBody TransferRequest request) {
        return transferService.create(request);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a transfer")
    public TransferResponse get(@PathVariable UUID id) {
        return transferService.get(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a transfer")
    public TransferResponse update(@PathVariable UUID id, @Valid @RequestBody TransferRequest request) {
        return transferService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a transfer",
            description = "Hard-deletes the transfer; derived account balances update automatically.")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        transferService.delete(id);
        return ResponseEntity.noContent().build();
    }
}