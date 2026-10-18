package com.blistra.ai;

import com.blistra.auth.security.AuthRateLimiter;
import com.blistra.common.time.UserTime;
import com.blistra.dashboard.application.DashboardService;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;

@Service
public class AiService {
    private final AiGateway gateway;
    private final CurrentUserProvider users;
    private final AuthRateLimiter limiter;
    private final DashboardService dashboard;
    private final UserTime time;
    private final JsonMapper mapper;
    private final boolean enabled;
    private final String instructions;

    public AiService(AiGateway gateway, CurrentUserProvider users, AuthRateLimiter limiter,
                     DashboardService dashboard, UserTime time, JsonMapper mapper,
                     @Value("${blistra.ai.enabled:false}") boolean enabled) throws IOException {
        this.gateway = gateway; this.users = users; this.limiter = limiter;
        this.dashboard = dashboard; this.time = time; this.mapper = mapper; this.enabled = enabled;
        instructions = new ClassPathResource("ai/blistra-assistant.md").getContentAsString(StandardCharsets.UTF_8);
    }

    public String chat(AiRequest request) {
        String reply = actionReply(request, null);
        return reply.length() > 4000 ? reply.substring(0, 4000) : reply;
    }

    public String actionReply(AiRequest request, String policy) {
        var user = users.getCurrentUser();
        if (!enabled) throw new AiUnavailableException();
        limiter.attempt("blistra-ai-user", user.getId().toString(), 20);
        limiter.attempt("blistra-ai-global", "all", 200);
        var messages = new ArrayList<Map<String, String>>();
        messages.add(Map.of("role", "system", "content", instructions));
        messages.add(Map.of("role", "system", "content", "Current user date: " + time.today()
                + "; timezone: " + time.zone() + ". Server summary: " + summary(Boolean.TRUE.equals(request.includeSummary()))));
        if (policy != null) messages.add(Map.of("role", "system", "content", policy));
        for (var turn : request.history()) messages.add(Map.of("role", turn.role(), "content", turn.content()));
        messages.add(Map.of("role", "user", "content", request.message().trim()));
        return gateway.reply(messages);
    }

    String summary(boolean include) {
        if (!include) return "Not shared. Answer product questions; ask the user for any needed personal facts.";
        var d = dashboard.getDashboard(time.today(), time.now().getOffset().getTotalSeconds() / 60);
        Map<String, Object> summary = new LinkedHashMap<>();
        // Deliberate allowlist: no identity, names, record IDs, notes or document contents.
        if (d.getPlanner() != null && !d.getPlanner().isUnavailable()) {
            var p = d.getPlanner();
            summary.put("planner", Map.of("todayTasks", size(p.getTodayTasks()),
                    "overdueTasks", size(p.getOverdueTasks()), "todayEvents", size(p.getTodayEvents())));
        }
        if (d.getHabits() != null && !d.getHabits().isUnavailable()) {
            var h = d.getHabits();
            summary.put("habits", Map.of("expected", h.getExpectedToday(), "completed", h.getCompletedToday()));
        }
        if (d.getMedicines() != null && !d.getMedicines().isUnavailable()) {
            var m = d.getMedicines();
            summary.put("medicines", Map.of("taken", m.getDosesTakenToday(), "remaining", m.getDosesRemainingToday()));
        }
        if (d.getDiet() != null && !d.getDiet().isUnavailable()) {
            var diet = d.getDiet();
            summary.put("diet", Map.of("mealsLogged", diet.getMealCount(),
                    "waterMilliliters", Objects.toString(diet.getWaterTotalMilliliters(), "unknown")));
        }
        summary.put("coverage", "Only today's planner, habit, medicine and diet counts. Missing sections unavailable. No health readings, finance amounts, historical records or documents shared.");
        return mapper.writeValueAsString(summary);
    }

    private static int size(List<?> list) { return list == null ? 0 : list.size(); }
}
