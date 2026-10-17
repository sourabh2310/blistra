package com.blistra.appupdate;

import com.blistra.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

class AppUpdateEndpointIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void latestIsPublicAndEmptyWhenNoSourceConfigured() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/app/latest")).andReturn();
        // Reachable without a token (not 401); tests disable GitHub, so 204.
        assertThat(result.getResponse().getStatus()).isEqualTo(204);

        MvcResult ios = mockMvc.perform(get("/api/v1/app/latest").param("platform", "ios")).andReturn();
        assertThat(ios.getResponse().getStatus()).isEqualTo(204);
    }
}
