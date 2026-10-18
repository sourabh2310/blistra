package com.blistra.documents.storage;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;

/** Bounded BYTEA storage: application restarts cannot discard committed uploads. */
@Service
@ConditionalOnProperty(name="blistra.documents.backend",havingValue="postgres")
@Transactional
public class PostgresDocumentStorage implements DocumentStorageService {
    private static final long MAX_OBJECT_BYTES=10L*1024*1024;
    private final JdbcTemplate jdbc;
    private final long budget;

    public PostgresDocumentStorage(JdbcTemplate jdbc,
            @Value("${blistra.documents.max-total-bytes:67108864}") long budget) {
        this.jdbc=jdbc; this.budget=budget;
    }
    @PostConstruct void validate() {
        if (budget<1) throw new IllegalStateException("Database upload budget must be positive");
    }

    @Override public long store(String key,InputStream content,long maxBytes) {
        validateKey(key);
        if (maxBytes<0) throw new IllegalArgumentException("Invalid upload limit");
        // The same global lock as file storage; it stays held until metadata commits.
        jdbc.execute("SELECT pg_advisory_xact_lock(191742031)");
        long used=jdbc.queryForObject("SELECT COALESCE(sum(byte_count),0) FROM document_objects",Long.class);
        long remaining=budget-used;
        if (remaining<=0) throw new StorageCapacityException();
        long limit=Math.min(maxBytes,MAX_OBJECT_BYTES);
        try (var bytes=new ByteArrayOutputStream()) {
            byte[] buffer=new byte[16384]; int count;
            while ((count=content.read(buffer))!=-1) {
                if ((long)bytes.size()+count>limit) throw new DocumentTooLargeException("File exceeds maximum allowed size");
                if ((long)bytes.size()+count>remaining) throw new StorageCapacityException();
                bytes.write(buffer,0,count);
            }
            byte[] data=bytes.toByteArray();
            jdbc.update("INSERT INTO document_objects(object_key,content,byte_count) VALUES (?,?,?)",key,data,data.length);
            return data.length;
        } catch (IOException e) { throw new DocumentStorageException("Could not read uploaded content",e); }
    }
    @Override @Transactional(readOnly=true) public Resource load(String key) {
        validateKey(key);
        var rows=jdbc.query("SELECT content FROM document_objects WHERE object_key=?",(rs,row)->rs.getBytes(1),key);
        if (rows.isEmpty()) throw new com.blistra.common.exception.ResourceNotFoundException(
            "File bytes are unavailable. Re-upload this older file or restore it from a backup.");
        return new ByteArrayResource(rows.getFirst());
    }
    @Override public void delete(String key) {
        if (key==null || key.isBlank()) return;
        validateKey(key);
        jdbc.update("DELETE FROM document_objects WHERE object_key=?",key);
    }
    @Override @Transactional(readOnly=true) public boolean exists(String key) {
        if (key==null || key.isBlank()) return false;
        validateKey(key);
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM document_objects WHERE object_key=?)",Boolean.class,key));
    }
    private void validateKey(String key) {
        try {
            if (key==null || !UUID.fromString(key).toString().equals(key)) throw new IllegalArgumentException();
        } catch (IllegalArgumentException e) { throw new DocumentStorageException("Invalid storage key"); }
    }
}
