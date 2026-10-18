package com.blistra.documents.storage;

import com.blistra.documents.config.DocumentsProperties;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.util.unit.DataSize;
import java.nio.file.*;
import java.io.ByteArrayInputStream;
import java.util.UUID;
import static org.assertj.core.api.Assertions.*;

class StorageCapacityTest {
    @TempDir Path root;
    @Test void globalBudgetCountsExistingAndOrphanBytesAndKeepsExistingFiles() throws Exception {
        var storage=new LocalFileSystemDocumentStorage(new DocumentsProperties(root,DataSize.ofMegabytes(10)));
        storage.init();
        ReflectionTestUtils.setField(storage,"maxTotalBytes",10L);
        Path prior=root.resolve(UUID.randomUUID().toString());Files.write(prior,new byte[8]);
        assertThatThrownBy(() -> storage.store(UUID.randomUUID().toString(),new ByteArrayInputStream(new byte[3]),3))
            .isInstanceOf(StorageCapacityException.class);
        assertThat(Files.size(prior)).isEqualTo(8);
        try (var files=Files.list(root)) { assertThat(files.count()).isEqualTo(1); }
        Files.delete(prior);
        String key=UUID.randomUUID().toString();
        assertThat(storage.store(key,new ByteArrayInputStream(new byte[3]),3)).isEqualTo(3);
        assertThat(storage.exists(key)).isTrue();
    }
    @Test void preservesTheVolumeFreeSpaceReserve() {
        var storage=new LocalFileSystemDocumentStorage(new DocumentsProperties(root,DataSize.ofMegabytes(10)));
        storage.init(); ReflectionTestUtils.setField(storage,"minFreeBytes",Long.MAX_VALUE);
        assertThatThrownBy(() -> storage.store(UUID.randomUUID().toString(),new ByteArrayInputStream(new byte[1]),1))
            .isInstanceOf(StorageCapacityException.class);
    }
}
