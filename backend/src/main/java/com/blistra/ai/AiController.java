package com.blistra.ai;

import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {
    private final AiService service;
    public AiController(AiService service) { this.service = service; }

    @PostMapping("/chat")
    public ResponseEntity<Map<String, String>> chat(@Valid @RequestBody AiRequest request) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(Map.of("reply", service.chat(request)));
    }

    @ExceptionHandler(AiUnavailableException.class)
    public ResponseEntity<Map<String, String>> unavailable(AiUnavailableException ex) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).cacheControl(CacheControl.noStore())
                .body(Map.of("code", "AI_UNAVAILABLE", "message", ex.getMessage()));
    }
}
