package com.blistra.common.monitoring;

import io.micrometer.prometheusmetrics.PrometheusMeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/** Opt-in operator endpoint; deliberately independent of app-account permissions. */
@RestController
public class OperatorMetricsController {
    private final PrometheusMeterRegistry meters;
    private final byte[] token;
    public OperatorMetricsController(PrometheusMeterRegistry meters,
            @Value("${BLISTRA_METRICS_TOKEN:}") String token) {
        if (!token.isEmpty() && token.length()<32) throw new IllegalStateException("BLISTRA_METRICS_TOKEN must contain at least 32 characters");
        this.meters=meters; this.token=token.getBytes(StandardCharsets.UTF_8);
    }
    @GetMapping(value="/internal/metrics",produces="text/plain; version=0.0.4; charset=utf-8")
    public ResponseEntity<String> scrape(@RequestHeader(value="X-Blistra-Metrics-Token",defaultValue="") String supplied) {
        if (token.length==0 || !MessageDigest.isEqual(token,supplied.getBytes(StandardCharsets.UTF_8)))
            return ResponseEntity.notFound().build();
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(meters.scrape());
    }
}
