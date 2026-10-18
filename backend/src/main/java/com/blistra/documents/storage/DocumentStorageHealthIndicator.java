package com.blistra.documents.storage;

import com.blistra.documents.config.DocumentsProperties;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;
import java.nio.file.Files;

/** Checks the selected storage backend without exposing diagnostics publicly. */
@Component("documentStorage")
public class DocumentStorageHealthIndicator implements HealthIndicator {
    private final DocumentsProperties properties;
    @org.springframework.beans.factory.annotation.Autowired private org.springframework.jdbc.core.JdbcTemplate jdbc;
    @org.springframework.beans.factory.annotation.Value("${blistra.documents.backend:filesystem}") private String backend;
    public DocumentStorageHealthIndicator(DocumentsProperties properties) { this.properties=properties; }
    @Override public Health health() {
        try {
            if ("postgres".equals(backend)) {
                jdbc.queryForObject("SELECT count(*) FROM document_objects WHERE false",Long.class);
                return Health.up().build();
            }
            var root=properties.storageRoot();
            if (!Files.isDirectory(root) || !Files.isWritable(root)
                    || Files.getFileStore(root).getUsableSpace()<50L*1024*1024) return Health.down().build();
            var probe=Files.createTempFile(root,".health-",".tmp");
            Files.delete(probe);
            return Health.up().build();
        } catch (Exception e) { return Health.down().build(); }
    }
}
