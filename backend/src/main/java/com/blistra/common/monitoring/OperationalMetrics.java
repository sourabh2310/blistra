package com.blistra.common.monitoring;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Fixed-cardinality, sampled worker metrics. Never tag by user, file or destination. */
@Component
@Slf4j
public class OperationalMetrics {
    private final JdbcTemplate jdbc;
    private final Map<String,Double> samples=new ConcurrentHashMap<>();
    private final java.nio.file.Path storageRoot;
    private final boolean databaseStorage;
    public OperationalMetrics(JdbcTemplate jdbc,MeterRegistry meters,
            com.blistra.documents.config.DocumentsProperties documents,
            @org.springframework.beans.factory.annotation.Value("${blistra.documents.max-total-bytes:0}") double configuredBudget,
            @org.springframework.beans.factory.annotation.Value("${blistra.documents.backend:filesystem}") String backend) {
        this.jdbc=jdbc;
        storageRoot=documents.storageRoot();
        databaseStorage="postgres".equals(backend);
        double storageBudget=configuredBudget>0 ? configuredBudget : (databaseStorage?67108864:838860800);
        samples.put("storage_used",0.0);
        Gauge.builder("blistra.storage.used.bytes",samples,m -> m.get("storage_used")).register(meters);
        Gauge.builder("blistra.storage.budget.bytes",() -> storageBudget).register(meters);
        if (!databaseStorage) Gauge.builder("blistra.storage.free.bytes",storageRoot,p -> {
            try { return java.nio.file.Files.getFileStore(p).getUsableSpace(); }
            catch (java.io.IOException e) { return Double.NaN; }
        }).register(meters);
        for (String queue : new String[]{"storage_deletion","otp_delivery"}) {
            for (String measure : new String[]{"pending","oldest_seconds","max_attempts"}) {
                String key=queue+"."+measure;
                samples.put(key,0.0);
                Gauge.builder("blistra.queue."+measure,samples,m -> m.get(key)).tag("queue",queue).register(meters);
            }
        }
        samples.put("last_success",0.0);
        Gauge.builder("blistra.queue.sample.timestamp.seconds",samples,m -> m.get("last_success")).register(meters);
    }
    @Scheduled(fixedDelayString="${blistra.monitoring.sample-delay-ms:60000}",
        initialDelayString="${blistra.monitoring.sample-initial-delay-ms:60000}")
    public void sample() {
        try {
            read("storage_deletion","storage_deletion_queue","queued_at");
            read("otp_delivery","otp_delivery_outbox","created_at");
            long used=0; int entries=0;
            if (databaseStorage) {
                used=jdbc.queryForObject("SELECT COALESCE(sum(byte_count),0) FROM document_objects",Long.class);
            } else try (var files=java.nio.file.Files.newDirectoryStream(storageRoot)) {
                for (var file:files) {
                    if (++entries>20000) throw new IllegalStateException("Storage sampling limit exceeded");
                    if (java.nio.file.Files.isRegularFile(file,java.nio.file.LinkOption.NOFOLLOW_LINKS)) used+=java.nio.file.Files.size(file);
                }
            }
            samples.put("storage_used",(double)used);
            samples.put("last_success",(double)java.time.Instant.now().getEpochSecond());
        } catch (RuntimeException | java.io.IOException e) {
            log.warn("Operational queue sampling failed ({})",e.getClass().getSimpleName());
        }
    }
    private void read(String queue,String table,String time) {
        // Identifiers are fixed above; no request or environment text reaches SQL.
        var row=jdbc.queryForMap("SELECT count(*) AS pending, COALESCE(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP-min("+time+"))),0) AS age, COALESCE(max(attempts),0) AS attempts FROM "+table);
        samples.put(queue+".pending",((Number)row.get("pending")).doubleValue());
        samples.put(queue+".oldest_seconds",Math.max(0,((Number)row.get("age")).doubleValue()));
        samples.put(queue+".max_attempts",((Number)row.get("attempts")).doubleValue());
        double age=samples.get(queue+".oldest_seconds");
        if (age>(queue.equals("otp_delivery")?120:3600))
            log.warn("Worker backlog queue={} pending={} oldestSeconds={}",queue,samples.get(queue+".pending"),age);
    }
}
