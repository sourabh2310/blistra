package com.blistra.ai;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/v1/ai/entries")
public class AiEntryController {
    public record Edit(@Min(1) int revision, @NotNull @Size(max = 80) Map<String, Object> data) {}
    public record Approval(@Min(1) int revision, @NotNull Boolean reviewed) {}
    public record Revision(@Min(1) int revision) {}
    private final AiEntryCatalog catalog;
    private final AiDraftService drafts;
    private final AiEntryAssistant assistant;
    public AiEntryController(AiEntryCatalog catalog, AiDraftService drafts, AiEntryAssistant assistant) {
        this.catalog = catalog; this.drafts = drafts; this.assistant = assistant;
    }
    private <T> ResponseEntity<T> response(T body) { return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(body); }
    @GetMapping("/catalog") public ResponseEntity<List<AiEntryCatalog.Entry>> catalog() { return response(catalog.entries()); }
    @PostMapping("/chat") public ResponseEntity<AiEntryAssistant.Reply> chat(@Valid @RequestBody AiEntryAssistant.Request request) { return response(assistant.respond(request)); }
    @GetMapping("/{id}") public ResponseEntity<AiDraftService.Draft> get(@PathVariable UUID id) { return response(drafts.get(id)); }
    @PutMapping("/{id}") public ResponseEntity<AiDraftService.Draft> edit(@PathVariable UUID id, @Valid @RequestBody Edit request) { return response(drafts.edit(id, request.revision, request.data)); }
    @PostMapping("/{id}/approve") public ResponseEntity<AiDraftService.Draft> approve(@PathVariable UUID id, @Valid @RequestBody Approval request) { return response(drafts.approve(id, request.revision, Boolean.TRUE.equals(request.reviewed))); }
    @PostMapping("/{id}/cancel") public ResponseEntity<Map<String, String>> cancel(@PathVariable UUID id, @Valid @RequestBody Revision request) {
        drafts.cancel(id, request.revision); return response(Map.of("state", "CANCELLED"));
    }
    @ExceptionHandler(AiUnavailableException.class) public ResponseEntity<Map<String, String>> unavailable(AiUnavailableException ex) {
        return ResponseEntity.status(503).cacheControl(CacheControl.noStore()).body(Map.of("code", "AI_UNAVAILABLE", "message", ex.getMessage()));
    }
}
