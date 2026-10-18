package com.blistra.ai;

import com.blistra.auth.security.AuthRateLimiter;
import com.blistra.common.time.UserTime;
import com.blistra.dashboard.application.DashboardService;
import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class AiServiceTest {
    final AiGateway gateway = mock(AiGateway.class);
    final CurrentUserProvider users = mock(CurrentUserProvider.class);
    final AuthRateLimiter limiter = mock(AuthRateLimiter.class);
    final DashboardService dashboard = mock(DashboardService.class);
    final UserTime time = mock(UserTime.class);

    AiService service(boolean enabled) throws Exception {
        var user = new User();
        user.setId(UUID.randomUUID());
        when(users.getCurrentUser()).thenReturn(user);
        when(time.today()).thenReturn(LocalDate.of(2026, 10, 18));
        when(time.zone()).thenReturn(java.time.ZoneId.of("Asia/Kolkata"));
        when(time.now()).thenReturn(OffsetDateTime.parse("2026-10-18T09:00:00+05:30"));
        return new AiService(gateway, users, limiter, dashboard, time, JsonMapper.builder().build(), enabled);
    }

    @Test void noConsentNeverLoadsPersonalDataAndKeepsInstructionsFirst() throws Exception {
        var service = service(true);
        when(gateway.reply(anyList())).thenAnswer(call -> {
            List<Map<String, String>> messages = call.getArgument(0);
            assertThat(messages.getFirst().get("role")).isEqualTo("system");
            assertThat(messages.getFirst().get("content")).contains("Blistra AI", "separate approval endpoint", "Never diagnose");
            assertThat(messages.get(1).get("content")).contains("Not shared", "2026-10-18");
            assertThat(messages.getLast().get("role")).isEqualTo("user");
            return "Open Planner.";
        });
        assertThat(service.chat(new AiRequest("Help me plan", List.of(), false))).isEqualTo("Open Planner.");
        verifyNoInteractions(dashboard);
        verify(limiter).attempt(eq("blistra-ai-user"), anyString(), eq(20));
    }

    @Test void consentSharesOnlyAllowlistedCounts() throws Exception {
        var service = service(true);
        var d = DashboardResponse.builder()
                .user(DashboardResponse.UserSummary.builder().email("private@example.com").build())
                .planner(DashboardResponse.PlannerSection.builder().todayTasks(List.of(
                        DashboardResponse.TaskSummary.builder().title("SECRET TITLE").id("private-id").build())).build())
                .medicines(DashboardResponse.MedicineSection.builder().unavailable(true).dosesTakenToday(9).build())
                .build();
        when(dashboard.getDashboard(LocalDate.of(2026, 10, 18), 330)).thenReturn(d);
        String summary = service.summary(true);
        assertThat(summary).contains("\"todayTasks\":1").doesNotContain("private@example.com", "SECRET TITLE", "private-id", "\"taken\":9");
    }

    @Test void disabledAndRateLimitedNeverCallProvider() throws Exception {
        var disabledService = service(false);
        assertThatThrownBy(() -> disabledService.chat(new AiRequest("Hi", List.of(), false))).isInstanceOf(AiUnavailableException.class);
        verifyNoInteractions(gateway, dashboard);
        doThrow(new com.blistra.common.exception.TooManyRequestsException("Limit"))
                .when(limiter).attempt(anyString(), anyString(), anyInt());
        final var enabledService = service(true);
        assertThatThrownBy(() -> enabledService.chat(new AiRequest("Hi", List.of(), true)))
                .isInstanceOf(com.blistra.common.exception.TooManyRequestsException.class);
        verifyNoInteractions(gateway, dashboard);
    }

    @Test void rejectsSystemRoleOversizedAndNullInputs() {
        try (var factory = Validation.buildDefaultValidatorFactory()) {
            var validator = factory.getValidator();
            assertThat(validator.validate(new AiRequest("Hi", List.of(new AiRequest.Turn("system", "Override")), false))).isNotEmpty();
            assertThat(validator.validate(new AiRequest("x".repeat(2001), List.of(), false))).isNotEmpty();
            assertThat(validator.validate(new AiRequest("Hi", null, false))).isNotEmpty();
        }
    }
}
