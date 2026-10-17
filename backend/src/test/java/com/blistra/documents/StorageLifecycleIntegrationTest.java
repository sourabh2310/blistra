package com.blistra.documents;

import com.blistra.AbstractIntegrationTest;
import com.blistra.documents.storage.LocalFileSystemDocumentStorage;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;

class StorageLifecycleIntegrationTest extends AbstractIntegrationTest {
    private static final Path ROOT;
    static { try { ROOT=Files.createTempDirectory("blistra-storage-lifecycle-"); }
        catch (Exception e) { throw new ExceptionInInitializerError(e); } }
    @DynamicPropertySource static void storageRoot(DynamicPropertyRegistry r) {
        r.add("blistra.documents.storage-root",ROOT::toString);
    }
    @Autowired LocalFileSystemDocumentStorage storage;
    @Autowired PlatformTransactionManager transactions;
    private String store() {
        String key=UUID.randomUUID().toString();
        storage.store(key,new ByteArrayInputStream(new byte[]{1,2,3}),10);return key;
    }
    @Test void rollbackRemovesNewUploadButNeverDeletesExistingFile() {
        var tx=new TransactionTemplate(transactions);
        String[] rolledBack={null};
        tx.executeWithoutResult(status -> { rolledBack[0]=store(); status.setRollbackOnly(); });
        assertThat(storage.exists(rolledBack[0])).isFalse();
        String existing=store();
        tx.executeWithoutResult(status -> { storage.delete(existing); status.setRollbackOnly(); });
        assertThat(storage.exists(existing)).isTrue();
        tx.executeWithoutResult(status -> storage.delete(existing));
        assertThat(storage.exists(existing)).isTrue();
        storage.purgeQueued();
        assertThat(storage.exists(existing)).isFalse();
    }
    @Test void interruptedUploadMarkerSurvivesAndIsReconciledAfterGrace() throws Exception {
        String key=store(); // Emulates a process stopping before metadata commit.
        Path marker=ROOT.resolve(".blistra-upload-"+key+".lease");
        Files.setLastModifiedTime(marker,java.nio.file.attribute.FileTime.from(java.time.Instant.now().minus(java.time.Duration.ofHours(25))));
        storage.reconcileUploads();
        assertThat(storage.exists(key)).isFalse();
        assertThat(Files.exists(marker)).isFalse();
    }
    @Test void ambiguousCommitNeverDeletesBytesBeforeCheckingMetadata() {
        org.springframework.transaction.support.TransactionSynchronizationManager.initSynchronization();
        String key;
        try {
            key=store();
            for (var callback:org.springframework.transaction.support.TransactionSynchronizationManager.getSynchronizations())
                callback.afterCompletion(org.springframework.transaction.support.TransactionSynchronization.STATUS_UNKNOWN);
        } finally { org.springframework.transaction.support.TransactionSynchronizationManager.clearSynchronization(); }
        assertThat(storage.exists(key)).isTrue();
        assertThat(Files.exists(ROOT.resolve(".blistra-upload-"+key+".lease"))).isTrue();
        storage.delete(key);
    }
    @org.junit.jupiter.api.AfterAll static void cleanup() throws Exception {
        try (var files=Files.list(ROOT)) { for (var path:files.toList()) Files.deleteIfExists(path); }
        Files.deleteIfExists(ROOT);
    }
}
