package com.blistra;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
public abstract class AbstractIntegrationTest {

    private static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine")
            .withDatabaseName("blistra_test")
            .withUsername("blistra_test")
            .withPassword("blistra_test");

    static {
        postgres.start();
    }

    @Autowired
    protected JdbcTemplate jdbcTemplate;

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        // Test-only JWT secret (>= 32 bytes). Production must supply JWT_SECRET
        // via the environment; the application fails startup without it.
        registry.add("JWT_SECRET", () -> "blistra-test-secret-0123456789abcdef-test-only");
    }

    /**
     * Removes all users. Finance tables deliberately do NOT cascade from
     * users (financial history must never be silently destroyed), so they have
     * to be cleared explicitly before the users they reference.
     */
    protected void deleteAllUsers() {
        jdbcTemplate.execute("DELETE FROM finance_transfers");
        jdbcTemplate.execute("DELETE FROM finance_transactions");
        jdbcTemplate.execute("DELETE FROM finance_categories");
        jdbcTemplate.execute("DELETE FROM finance_accounts");
        jdbcTemplate.execute("DELETE FROM users");
    }
}
