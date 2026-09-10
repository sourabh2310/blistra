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
public class LocalFileSystemDocumentStorage implements DocumentStorageService {

    private static final Logger log = LoggerFactory.getLogger(LocalFileSystemDocumentStorage.class);

    private final DocumentsProperties properties;
    private final Path root;

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
        try {
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
            log.debug("Stored document {} ({} bytes)", objectKey, written);
            return written;
        } catch (DocumentTooLargeException e) {
            deleteQuietly(tempFile);
            throw e;
        } catch (IOException e) {
            deleteQuietly(tempFile);
            throw new DocumentStorageException("Failed to store document: " + objectKey, e);
        }
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