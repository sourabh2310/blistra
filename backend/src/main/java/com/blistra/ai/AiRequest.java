package com.blistra.ai;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;

public record AiRequest(
        @NotBlank @Size(max = 2000) String message,
        @NotNull @Size(max = 10) List<@NotNull @Valid Turn> history,
        Boolean includeSummary) {
    public record Turn(@NotNull @Pattern(regexp = "user|assistant") String role,
                       @NotBlank @Size(max = 4000) String content) {}
}
