package com.blistra.auth.security;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.users.domain.UserStatus;
import com.blistra.users.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SecurityIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    private static final String REGISTER_URL = "/api/v1/auth/register";
    private static final String LOGIN_URL = "/api/v1/auth/login";
    private static final String HEALTH_URL = "/health";

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void testPublicEndpointAccessWithoutAuthentication() throws Exception {
        mockMvc.perform(get(HEALTH_URL))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void testAuthenticatedIdentityResolution() throws Exception {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .email("test@example.com")
                .password("password123")
                .build();

        mockMvc.perform(post(REGISTER_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(registerRequest)))
                .andExpect(status().isCreated());

        LoginRequest loginRequest = LoginRequest.builder()
                .email("test@example.com")
                .password("password123")
                .build();

        MvcResult loginResult = mockMvc.perform(post(LOGIN_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        String responseBody = loginResult.getResponse().getContentAsString();
        String token = jsonMapper.readTree(responseBody).get("token").asText();

        assertThat(token).isNotEmpty();
        String[] tokenParts = token.split("\\.");
        assertThat(tokenParts.length).isEqualTo(3);
    }

    // Must match the test-only JWT_SECRET registered in AbstractIntegrationTest.
    private static final String TEST_JWT_SECRET = "blistra-test-secret-0123456789abcdef-test-only";
    private static final String ACCOUNTS_URL = "/api/v1/finance/accounts";

    private SecretKey testSigningKey() {
        return Keys.hmacShaKeyFor(TEST_JWT_SECRET.getBytes(StandardCharsets.UTF_8));
    }

    private String registerAndLogin(String email, String password) throws Exception {
        mockMvc.perform(post(REGISTER_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(RegisterRequest.builder()
                        .email(email).password(password).build())))
                .andExpect(status().isCreated());

        MvcResult loginResult = mockMvc.perform(post(LOGIN_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(LoginRequest.builder()
                        .email(email).password(password).build())))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(loginResult.getResponse().getContentAsString()).get("token").asText();
    }

    @Test
    void testMissingTokenIsRejectedForProtectedEndpoint() throws Exception {
        mockMvc.perform(get(ACCOUNTS_URL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testValidTokenAuthenticatesProtectedEndpoint() throws Exception {
        String token = registerAndLogin("jwt-valid@example.com", "password123");

        mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @Test
    void testMalformedJwtIsRejectedWithoutLeakingToken() throws Exception {
        String malformed = "this.is.not-a-valid-jwt";

        MvcResult result = mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + malformed))
                .andExpect(status().isUnauthorized())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain(malformed);
        assertThat(body).doesNotContain("this.is");
    }

    @Test
    void testInvalidSignatureJwtIsRejected() throws Exception {
        registerAndLogin("jwt-sig@example.com", "password123");
        SecretKey otherKey = Keys.hmacShaKeyFor(
                "a-completely-different-test-secret-0123456789".getBytes(StandardCharsets.UTF_8));
        String forged = Jwts.builder()
                .subject("jwt-sig@example.com")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 3_600_000))
                .signWith(otherKey)
                .compact();

        MvcResult result = mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized())
                .andReturn();

        assertThat(result.getResponse().getContentAsString()).doesNotContain(forged);
    }

    @Test
    void testExpiredJwtIsRejected() throws Exception {
        registerAndLogin("jwt-expired@example.com", "password123");
        String expired = Jwts.builder()
                .subject("jwt-expired@example.com")
                .issuedAt(new Date(System.currentTimeMillis() - 7_200_000))
                .expiration(new Date(System.currentTimeMillis() - 3_600_000))
                .signWith(testSigningKey())
                .compact();

        MvcResult result = mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andReturn();

        assertThat(result.getResponse().getContentAsString()).doesNotContain(expired);
    }

    @Test
    void testSuspendedUserTokenIsRejectedOnProtectedEndpoint() throws Exception {
        String token = registerAndLogin("jwt-suspended@example.com", "password123");

        mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        var user = userRepository.findByEmail("jwt-suspended@example.com").orElseThrow();
        user.setStatus(UserStatus.SUSPENDED);
        userRepository.save(user);

        mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testActuatorHealthIsPublicButSensitiveEndpointsAreNot() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk());

        for (String sensitive : new String[]{"/actuator/env", "/actuator/beans", "/actuator/mappings"}) {
            MvcResult result = mockMvc.perform(get(sensitive)).andReturn();
            assertThat(result.getResponse().getStatus())
                    .as("sensitive actuator endpoint %s must not be anonymously accessible", sensitive)
                    .isNotEqualTo(200);
        }
    }

    @Test
    void testAccessPublicSwaggerUiWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/swagger-ui.html"))
                .andExpect(status().is3xxRedirection())
                .andExpect(redirectedUrl("/swagger-ui/index.html"));

        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());
    }
}
