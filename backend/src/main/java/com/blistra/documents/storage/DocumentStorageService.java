package com.blistra.documents.storage;

import org.springframework.core.io.Resource;

public interface DocumentStorageService {
    /**
     * Stores the given content under the specified object key.
     * Enforces the maximum byte limit during the write.
     *
     * @param objectKey  the unique storage key (server-generated)
     * @param content    the input stream to read content from
     * @param maxBytes   maximum allowed bytes (enforced during write)
     * @return the number of bytes actually stored
     * @throws DocumentStorageException if storage fails
     * @throws DocumentTooLargeException if the content exceeds maxBytes
     */
    long store(String objectKey, java.io.InputStream content, long maxBytes) throws DocumentStorageException, DocumentTooLargeException;

    /**
     * Loads the stored content as a Spring Resource for streaming.
     *
     * @param objectKey the storage key
     * @return a Resource pointing to the stored file
     * @throws DocumentStorageException if the file does not exist or cannot be accessed
     */
    Resource load(String objectKey) throws DocumentStorageException;

    /**
     * Deletes the stored file.
     *
     * @param objectKey the storage key
     * @throws DocumentStorageException if deletion fails
     */
    void delete(String objectKey) throws DocumentStorageException;

    /**
     * Checks if a file exists for the given object key.
     *
     * @param objectKey the storage key
     * @return true if the file exists, false otherwise
     */
    boolean exists(String objectKey);
}