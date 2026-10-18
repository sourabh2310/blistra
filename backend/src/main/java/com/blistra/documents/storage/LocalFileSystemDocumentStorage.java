package com.blistra.documents.storage;

import com.blistra.documents.config.DocumentsProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

@Service
@org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(name="blistra.documents.backend",havingValue="filesystem",matchIfMissing=true)
public class LocalFileSystemDocumentStorage implements DocumentStorageService {

    private static final Logger log = LoggerFactory.getLogger(LocalFileSystemDocumentStorage.class);

    private final DocumentsProperties properties;
    private final Path root;
    private org.springframework.jdbc.core.JdbcTemplate jdbc;
    private org.springframework.transaction.support.TransactionTemplate independent;
    @org.springframework.beans.factory.annotation.Value("${blistra.documents.max-total-bytes:838860800}")
    private long maxTotalBytes=838860800L;
    @org.springframework.beans.factory.annotation.Value("${blistra.documents.min-free-bytes:52428800}")
    private long minFreeBytes=52428800L;

    @org.springframework.beans.factory.annotation.Autowired
    void configureLifecycle(org.springframework.jdbc.core.JdbcTemplate jdbc,
                            org.springframework.transaction.PlatformTransactionManager transactions) {
        this.jdbc = jdbc;
        independent = new org.springframework.transaction.support.TransactionTemplate(transactions);
        independent.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    public LocalFileSystemDocumentStorage(DocumentsProperties properties) {
        this.properties = properties;
        this.root = properties.storageRoot().toAbsolutePath().normalize();
    }

    @PostConstruct
    public void init() {
        try {
            Files.createDirectories(root);
            log.debug("Document storage root initialized at: {}", root);
        } catch (IOException e) {
            throw new DocumentStorageException("Failed to create storage root directory: " + root, e);
        }
    }

    @Override
    public long store(String objectKey, InputStream content, long maxBytes)
            throws DocumentStorageException, DocumentTooLargeException {

        if (objectKey == null || objectKey.isBlank()) {
            throw new DocumentStorageException("Object key must not be empty");
        }
        if (!isSafeObjectKey(objectKey)) {
            throw new DocumentStorageException("Invalid object key format");
        }

        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            throw new DocumentStorageException("Object key resolves outside storage root");
        }

        Path tempFile = null;
        long written = 0;
        Path lease=root.resolve(".blistra-upload-"+objectKey+".lease");
        try {
            checkCapacity(maxBytes);
            // Filesystem marker survives a process crash without borrowing a
            // second DB connection while the upload transaction holds one.
            Files.createFile(lease);
            tempFile = Files.createTempFile(root, ".blistra-", ".tmp");
            try (OutputStream out = Files.newOutputStream(tempFile)) {
                byte[] buffer = new byte[16384];
                int n;
                while ((n = content.read(buffer)) != -1) {
                    written += n;
                    if (written > maxBytes) {
                        throw new DocumentTooLargeException(
                                "File exceeds maximum allowed size of " + maxBytes + " bytes");
                    }
                    out.write(buffer, 0, n);
                }
            }
            Files.move(tempFile, target, StandardCopyOption.ATOMIC_MOVE);
            tempFile = null; // moved successfully
            if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
                org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                        new org.springframework.transaction.support.TransactionSynchronization() {
                            @Override public void afterCompletion(int status) {
                                if (status == STATUS_ROLLED_BACK) {
                                    try { deletePhysical(objectKey); }
                                    catch (RuntimeException e) { log.warn("Rolled-back upload cleanup deferred"); }
                                } else if (status == STATUS_COMMITTED) {
                                    deleteQuietly(lease);
                                } else {
                                    // A lost commit acknowledgement is ambiguous:
                                    // keep bytes until the reconciler checks DB references.
                                    log.warn("Upload transaction outcome unknown; reconciliation marker retained");
                                }
                            }
                        });
            }
            log.debug("Stored document {} ({} bytes)", objectKey, written);
            return written;
        } catch (DocumentTooLargeException e) {
            deleteQuietly(tempFile);
            deleteQuietly(lease);
            throw e;
        } catch (IOException e) {
            deleteQuietly(tempFile);
            if (tempFile != null) deleteQuietly(lease);
            throw new DocumentStorageException("Failed to store document: " + objectKey, e);
        }
    }

    private void checkCapacity(long reservation) throws IOException {
        if (reservation<0 || maxTotalBytes<1 || minFreeBytes<0)
            throw new IllegalStateException("Invalid storage capacity configuration");
        if (jdbc!=null && org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive()) {
            // All document/avatar requests already own a transaction. One
            // cross-instance lock serializes capacity checks until commit,
            // without borrowing another connection or releasing early.
            jdbc.execute("SELECT pg_advisory_xact_lock(191742031)");
        }
        long total=0; int entries=0;
        try (var files=Files.newDirectoryStream(root)) {
            for (Path file:files) {
                if (++entries>20000) throw new StorageCapacityException();
                if (Files.isRegularFile(file,java.nio.file.LinkOption.NOFOLLOW_LINKS)) total+=Files.size(file);
                if (total>maxTotalBytes) throw new StorageCapacityException();
            }
        }
        if (reservation>maxTotalBytes-total || Files.getFileStore(root).getUsableSpace()-reservation<minFreeBytes)
            throw new StorageCapacityException();
    }

    @Override
    public Resource load(String objectKey) throws DocumentStorageException {
        if (objectKey == null || objectKey.isBlank()) {
            throw new DocumentStorageException("Object key must not be empty");
        }
        if (!isSafeObjectKey(objectKey)) {
            throw new DocumentStorageException("Invalid object key format");
        }

        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            throw new DocumentStorageException("Object key resolves outside storage root");
        }

        if (!Files.exists(target) || !Files.isRegularFile(target)) {
            throw new DocumentStorageException("Document not found: " + objectKey);
        }

        return new FileSystemResource(target);
    }

    @Override
    public void delete(String objectKey) throws DocumentStorageException {
        if (objectKey != null && !objectKey.isBlank() && jdbc != null
                && org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive()) {
            if (!isSafeObjectKey(objectKey)) throw new DocumentStorageException("Invalid object key format");
            enqueue(objectKey);
            // The worker runs after commit, without retaining the request's
            // connection while trying to acquire another from a small pool.
            return;
        }
        deletePhysical(objectKey);
    }

    private void enqueue(String objectKey) {
        jdbc.update("INSERT INTO storage_deletion_queue(object_key) VALUES (?) ON CONFLICT DO NOTHING", objectKey);
    }

    @org.springframework.scheduling.annotation.Scheduled(fixedDelayString = "${blistra.documents.cleanup-interval-ms:60000}", initialDelayString = "${blistra.documents.cleanup-initial-delay-ms:60000}")
    public void purgeQueued() {
        if (jdbc == null) return;
        // Separate commits: a storage outage must not roll back user deletion.
        try {
            independent.executeWithoutResult(tx -> {
                var keys = jdbc.queryForList("SELECT object_key FROM storage_deletion_queue ORDER BY queued_at LIMIT 100 FOR UPDATE SKIP LOCKED", String.class);
                for (String key : keys) {
                    try {
                        deletePhysical(key);
                        jdbc.update("DELETE FROM storage_deletion_queue WHERE object_key = ?", key);
                    } catch (RuntimeException e) {
                        jdbc.update("UPDATE storage_deletion_queue SET attempts = attempts + 1 WHERE object_key = ?", key);
                        log.warn("Storage deletion pending; retry retained for key {}", key);
                    }
                }
            });
        } catch (RuntimeException e) {
            log.warn("Storage deletion worker unavailable ({})", e.getClass().getSimpleName());
        }
    }

    @org.springframework.scheduling.annotation.Scheduled(fixedDelayString = "${blistra.documents.reconcile-interval-ms:3600000}", initialDelayString = "${blistra.documents.reconcile-initial-delay-ms:60000}")
    public void reconcileUploads() {
        if (jdbc == null) return;
        try {
            long cutoff=System.currentTimeMillis()-java.time.Duration.ofHours(24).toMillis();
            try (var leases=Files.newDirectoryStream(root,".blistra-upload-*.lease")) {
                int checked=0;
                for (Path lease:leases) {
                    if (Files.getLastModifiedTime(lease).toMillis()>=cutoff) continue;
                    if (checked++>=100) break;
                    String name=lease.getFileName().toString();
                    String key=name.substring(".blistra-upload-".length(),name.length()-".lease".length());
                    if (!isSafeObjectKey(key)) continue;
                    independent.executeWithoutResult(tx -> {
                        Boolean referenced=jdbc.queryForObject("""
                        SELECT EXISTS(SELECT 1 FROM documents WHERE stored_object_key=?)
                            OR EXISTS(SELECT 1 FROM user_profiles WHERE avatar_object_key=?)
                        """,Boolean.class,key,key);
                        if (!Boolean.TRUE.equals(referenced)) deletePhysical(key);
                        else deleteQuietly(lease);
                    });
                }
            }
            // Only this service's interrupted stream files, with a 24-hour grace.
            try (var files=Files.newDirectoryStream(root,".blistra-*.tmp")) {
                for (Path file:files) if (Files.getLastModifiedTime(file).toMillis()<cutoff) deleteQuietly(file);
            }
        } catch (RuntimeException | IOException e) { log.warn("Storage reconciliation deferred ({})",e.getClass().getSimpleName()); }
    }

    private void deletePhysical(String objectKey) throws DocumentStorageException {
        if (objectKey == null || objectKey.isBlank()) {
            return;
        }
        if (!isSafeObjectKey(objectKey)) {
            throw new DocumentStorageException("Invalid object key format");
        }

        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            throw new DocumentStorageException("Object key resolves outside storage root");
        }

        try {
            boolean deleted = Files.deleteIfExists(target);
            Files.deleteIfExists(root.resolve(".blistra-upload-"+objectKey+".lease"));
            if (deleted) {
                log.debug("Deleted document: {}", objectKey);
            } else {
                log.debug("Document already absent: {}", objectKey);
            }
        } catch (IOException e) {
            throw new DocumentStorageException("Failed to delete document: " + objectKey, e);
        }
    }

    @Override
    public boolean exists(String objectKey) {
        if (objectKey == null || objectKey.isBlank()) {
            return false;
        }
        if (!isSafeObjectKey(objectKey)) {
            return false;
        }
        Path target = root.resolve(objectKey).normalize();
        if (!target.startsWith(root)) {
            return false;
        }
        return Files.exists(target) && Files.isRegularFile(target);
    }

    private boolean isSafeObjectKey(String objectKey) {
        // Object keys are server-generated UUIDs; ensure they only contain valid UUID chars
        return objectKey.matches("[0-9a-fA-F-]{36}");
    }

    private void deleteQuietly(Path path) {
        if (path != null) {
            try {
                Files.deleteIfExists(path);
            } catch (IOException ignored) {
            }
        }
    }
}
