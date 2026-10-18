package com.blistra.ai;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.util.List;
import java.util.Map;

@Component
public class FreeLlmGateway implements AiGateway {
    private final JsonMapper mapper;
    private final String key;
    private final String model;
    private final URI endpoint;
    @Value("${blistra.ai.max-tokens:2048}") private int maxTokens = 2048;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5)).followRedirects(HttpClient.Redirect.NEVER).build();

    public FreeLlmGateway(JsonMapper mapper,
            @Value("${blistra.ai.api-key:}") String key,
            @Value("${blistra.ai.base-url:http://127.0.0.1:31415/v1}") String baseUrl,
            @Value("${blistra.ai.model:auto}") String model) {
        this.mapper = mapper;
        this.key = key;
        this.model = model;
        URI base = URI.create(baseUrl.replaceAll("/+$", ""));
        boolean loopback = List.of("127.0.0.1", "localhost", "[::1]").contains(base.getHost());
        if (base.getHost() == null || base.getUserInfo() != null || base.getQuery() != null
                || base.getFragment() != null || !("https".equals(base.getScheme())
                || ("http".equals(base.getScheme()) && loopback))) {
            throw new IllegalArgumentException("AI base URL requires HTTPS (HTTP allowed only on loopback)");
        }
        this.endpoint = URI.create(base + "/chat/completions");
    }

    @Override
    public String reply(List<Map<String, String>> messages) {
        if (key == null || key.isBlank()) throw new AiUnavailableException();
        try {
            Map<String, Object> payload = new java.util.LinkedHashMap<>(Map.of(
                    "model", model, "messages", messages, "temperature", 0.2,
                    "max_tokens", Math.max(256, Math.min(4096, maxTokens)), "stream", false));
            if (model.startsWith("openai/gpt-oss-")) payload.put("reasoning_effort", "low");
            var request = HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(45))
                    .header("Authorization", "Bearer " + key)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(payload))).build();
            // Read at most 64 KiB even if a malfunctioning provider sends an oversized body.
            var response = http.send(request, info -> new LimitedBody());
            byte[] bytes = response.body();
            if (response.statusCode() != 200 || bytes.length > 65536) throw new AiUnavailableException();
            var root = mapper.readTree(bytes);
            String content = root.path("choices").path(0).path("message").path("content").asString("");
            if (content.isBlank() || content.length() > 16000) throw new AiUnavailableException();
            return content.trim();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new AiUnavailableException();
        } catch (IOException | RuntimeException e) {
            // Never expose/log keys, prompts, personal data or provider error bodies.
            throw new AiUnavailableException();
        }
    }

    /** Bounded subscriber keeps the request deadline active until the full body arrives. */
    private static final class LimitedBody implements HttpResponse.BodySubscriber<byte[]> {
        private final java.util.concurrent.CompletableFuture<byte[]> result = new java.util.concurrent.CompletableFuture<>();
        private final java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
        private java.util.concurrent.Flow.Subscription subscription;
        public java.util.concurrent.CompletionStage<byte[]> getBody() { return result; }
        public void onSubscribe(java.util.concurrent.Flow.Subscription s) { subscription = s; s.request(1); }
        public void onNext(List<java.nio.ByteBuffer> chunks) {
            for (var chunk : chunks) {
                if (bytes.size() + chunk.remaining() > 65536) {
                    subscription.cancel(); result.completeExceptionally(new IOException("AI response too large")); return;
                }
                byte[] part = new byte[chunk.remaining()]; chunk.get(part); bytes.writeBytes(part);
            }
            subscription.request(1);
        }
        public void onError(Throwable error) { result.completeExceptionally(error); }
        public void onComplete() { result.complete(bytes.toByteArray()); }
    }
}
