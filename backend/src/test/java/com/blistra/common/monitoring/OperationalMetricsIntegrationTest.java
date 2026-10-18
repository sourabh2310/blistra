package com.blistra.common.monitoring;

import com.blistra.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@TestPropertySource(properties="BLISTRA_METRICS_TOKEN=test-operator-secret-minimum-32-characters")
class OperationalMetricsIntegrationTest extends AbstractIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired OperationalMetrics metrics;
    @Test void onlyOperatorTokenCanReadMetricsAndQueueGaugesExposeNoRecordKeys() throws Exception {
        mvc.perform(get("/internal/metrics")).andExpect(status().isNotFound());
        mvc.perform(get("/internal/metrics").header("X-Blistra-Metrics-Token","incorrect"))
            .andExpect(status().isNotFound());
        String object="00000000-0000-0000-0000-000000000001";
        try {
            jdbcTemplate.update("INSERT INTO storage_deletion_queue(object_key,queued_at,attempts) VALUES (?,CURRENT_TIMESTAMP - INTERVAL '2 hours',3)",object);
            metrics.sample();
            String output=mvc.perform(get("/internal/metrics")
                .header("X-Blistra-Metrics-Token","test-operator-secret-minimum-32-characters"))
                .andExpect(status().isOk()).andExpect(header().string("Cache-Control","no-store"))
                .andReturn().getResponse().getContentAsString();
            assertThat(output).contains("blistra_queue_pending","queue=\"storage_deletion\"",
                "blistra_queue_oldest_seconds","blistra_queue_max_attempts","jvm_memory_used_bytes");
            assertThat(output).doesNotContain(object,"passwordHash","example.com");
        } finally { jdbcTemplate.update("DELETE FROM storage_deletion_queue WHERE object_key=?",object); }
    }
}
