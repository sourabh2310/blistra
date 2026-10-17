package com.blistra.documents.storage;

import com.blistra.documents.config.DocumentsProperties;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;
import java.nio.file.Files;

/** Readiness fails when the upload volume is absent, unwritable or full. */
@Component("documentStorage")
public class DocumentStorageHealthIndicator implements HealthIndicator {
    private final DocumentsProperties properties;
    public DocumentStorageHealthIndicator(DocumentsProperties properties) { this.properties=properties; }
    @Override public Health health() {
        try {
            var root=properties.storageRoot();
            if (!Files.isDirectory(root) || !Files.isWritable(root)
                    || Files.getFileStore(root).getUsableSpace()<50L*1024*1024) return Health.down().build();
            var probe=Files.createTempFile(root,".health-",".tmp");
            Files.delete(probe);
            return Health.up().build();
        } catch (Exception e) { return Health.down().build(); }
    }
}
