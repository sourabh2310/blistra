package com.blistra.documents;

import com.blistra.auth.AuthFlowTest;
import com.blistra.documents.storage.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@TestPropertySource(properties={"blistra.documents.backend=postgres",
    "blistra.documents.storage-root=/not-a-mounted-volume",
    "blistra.documents.max-total-bytes=64"})
class PostgresStorageIntegrationTest extends AuthFlowTest {
    @Autowired DocumentStorageService storage;
    @Autowired PlatformTransactionManager manager;
    @BeforeEach void clean() { deleteAllUsers(); }
    private final byte[] pdf="%PDF-1.4\nsmall test document".getBytes(StandardCharsets.UTF_8);
    private MockMultipartFile pdf() { return new MockMultipartFile("file","test.pdf","application/pdf",pdf); }
    private int objects() { return jdbcTemplate.queryForObject("SELECT count(*) FROM document_objects",Integer.class); }

    @Test void committedBytesSurviveNewStorageInstancesWithoutAnyMountedDirectory() throws Exception {
        String key=UUID.randomUUID().toString();
        storage.store(key,new ByteArrayInputStream(pdf),pdf.length);
        var restarted=new PostgresDocumentStorage(jdbcTemplate,64);
        assertThat(restarted.load(key).getInputStream().readAllBytes()).isEqualTo(pdf);
        mockMvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
        storage.delete(key);storage.delete(key);
        assertThat(storage.exists(key)).isFalse();
    }
    @Test void rollbackRestoresBothDocumentMetadataAndBytes() throws Exception {
        String token=tokenOf(registerFull("dbfiles","dbfiles@example.com",null,"password1"));
        var tx=new TransactionTemplate(manager);
        tx.executeWithoutResult(status -> {
            try {
                mockMvc.perform(multipart("/api/v1/documents").file(pdf()).param("category","OTHER").header("Authorization","Bearer "+token))
                    .andExpect(status().isCreated());
                assertThat(objects()).isEqualTo(1);
            } catch (Exception e) { throw new IllegalStateException(e); }
            status.setRollbackOnly();
        });
        assertThat(objects()).isZero();
        assertThat(jdbcTemplate.queryForObject("SELECT count(*) FROM documents",Integer.class)).isZero();
        var result=mockMvc.perform(multipart("/api/v1/documents").file(pdf()).param("category","OTHER").header("Authorization","Bearer "+token))
            .andExpect(status().isCreated()).andReturn();
        String id=jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asString();
        tx.executeWithoutResult(status -> {
            try { mockMvc.perform(delete("/api/v1/documents/"+id).header("Authorization","Bearer "+token))
                .andExpect(status().isNoContent()); }
            catch (Exception e) { throw new IllegalStateException(e); }
            assertThat(objects()).isZero();status.setRollbackOnly();
        });
        assertThat(objects()).isEqualTo(1);
        mockMvc.perform(get("/api/v1/documents/"+id+"/content").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(content().bytes(pdf));
        String other=tokenOf(registerFull("otherdb","otherdb@example.com",null,"password1"));
        mockMvc.perform(get("/api/v1/documents/"+id+"/content").header("Authorization","Bearer "+other))
            .andExpect(status().isNotFound());
    }
    @Test void concurrentWritesShareOneBudgetAndRejectsDoNotLeavePartialObjects() throws Exception {
        var start=new CyclicBarrier(2);
        try (var pool=Executors.newFixedThreadPool(2)) {
            Callable<Boolean> write=() -> {
                start.await(5,TimeUnit.SECONDS);
                try { storage.store(UUID.randomUUID().toString(),new ByteArrayInputStream(new byte[40]),40); return true; }
                catch (StorageCapacityException e) { return false; }
            };
            var a=pool.submit(write);var b=pool.submit(write);
            assertThat(java.util.List.of(a.get(10,TimeUnit.SECONDS),b.get(10,TimeUnit.SECONDS)))
                .containsExactlyInAnyOrder(true,false);
        }
        assertThat(objects()).isEqualTo(1);
        assertThatThrownBy(() -> storage.store(UUID.randomUUID().toString(),new ByteArrayInputStream(new byte[6]),5))
            .isInstanceOf(DocumentTooLargeException.class);
        assertThat(objects()).isEqualTo(1);
    }
    @Test void accountDeactivationKeepsDocumentAndAvatarBytesInTheDatabase() throws Exception {
        String token=tokenOf(registerFull("deletefiles","deletefiles@example.com",null,"password1"));
        mockMvc.perform(multipart("/api/v1/documents").file(pdf()).param("category","OTHER").header("Authorization","Bearer "+token))
            .andExpect(status().isCreated());
        byte[] png={(byte)0x89,'P','N','G',13,10,26,10,0};
        mockMvc.perform(multipart("/api/v1/profile/avatar")
            .file(new MockMultipartFile("file","photo.png","image/png",png)).header("Authorization","Bearer "+token))
            .andExpect(status().isOk());
        assertThat(objects()).isEqualTo(2);
        mockMvc.perform(post("/api/v1/profile/delete-account").header("Authorization","Bearer "+token)
            .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content("{\"currentPassword\":\"password1\"}"))
            .andExpect(status().isNoContent());
        assertThat(objects()).isEqualTo(2);
    }
}
