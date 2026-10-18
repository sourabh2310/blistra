package com.blistra.ai;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static org.assertj.core.api.Assertions.*;

class FreeLlmGatewayTest {
    final JsonMapper mapper = JsonMapper.builder().build();

    @Test void usesConfiguredEndpointBearerAndOpenAiContract() throws Exception {
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        var requests = new ArrayList<String>();
        server.createContext("/v1/chat/completions", exchange -> {
            requests.add(exchange.getRequestHeaders().getFirst("Authorization"));
            requests.add(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] body = "{\"choices\":[{\"message\":{\"content\":\"Use Planner.\"}}]}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            try (var out = exchange.getResponseBody()) { out.write(body); }
        });
        server.start();
        try {
            var gateway = new FreeLlmGateway(mapper, "test-key", "http://127.0.0.1:" + server.getAddress().getPort() + "/v1", "auto");
            assertThat(gateway.reply(List.of(Map.of("role", "user", "content", "Help")))).isEqualTo("Use Planner.");
            assertThat(requests.getFirst()).isEqualTo("Bearer test-key");
            assertThat(requests.get(1)).contains("\"model\":\"auto\"", "\"stream\":false");
        } finally { server.stop(0); }
    }

    @Test void missingKeyAndInsecureRemoteFailSafely() {
        assertThatThrownBy(() -> new FreeLlmGateway(mapper, "", "http://127.0.0.1:31415/v1", "auto").reply(List.of()))
                .isInstanceOf(AiUnavailableException.class).hasMessageNotContaining("31415");
        assertThatThrownBy(() -> new FreeLlmGateway(mapper, "secret", "http://external.example/v1", "auto"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test void rejectsProviderErrorsMalformedEmptyAndOversizedResponses() throws Exception {
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        final int[] status = {200};
        final String[] response = {""};
        server.createContext("/v1/chat/completions", exchange -> {
            exchange.getRequestBody().readAllBytes();
            byte[] body = response[0].getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status[0], body.length);
            try (var out = exchange.getResponseBody()) { out.write(body); }
        });
        server.start();
        try {
            var gateway = new FreeLlmGateway(mapper, "private-key", "http://127.0.0.1:" + server.getAddress().getPort() + "/v1", "auto");
            for (String body : List.of("not-json", "{}", "x".repeat(65537))) {
                response[0] = body;
                assertThatThrownBy(() -> gateway.reply(List.of())).isInstanceOf(AiUnavailableException.class);
            }
            status[0] = 429;
            response[0] = "private-key provider details";
            assertThatThrownBy(() -> gateway.reply(List.of())).isInstanceOf(AiUnavailableException.class)
                    .hasMessageNotContaining("private-key").hasMessageNotContaining("provider details");
        } finally { server.stop(0); }
    }
}
