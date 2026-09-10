package com.blistra.finance;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.node.ObjectNode;
import tools.jackson.databind.json.JsonMapper;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Shared infrastructure for finance integration tests.
 *
 * <p>Finance rows reference users, so the finance tables must be truncated
 * before the user table is cleared.</p>
 */
public abstract class FinanceTestSupport extends AbstractIntegrationTest {

    protected static final String REGISTER_URL = "/api/v1/auth/register";
    protected static final String LOGIN_URL = "/api/v1/auth/login";

    protected static final String ACCOUNTS_URL = "/api/v1/finance/accounts";
    protected static final String CATEGORIES_URL = "/api/v1/finance/categories";
    protected static final String TRANSACTIONS_URL = "/api/v1/finance/transactions";
    protected static final String TRANSFERS_URL = "/api/v1/finance/transfers";
    protected static final String SUMMARY_URL = "/api/v1/finance/summary";

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JsonMapper jsonMapper;

    @Autowired
    protected UserRepository userRepository;

    @Autowired
    protected com.blistra.finance.repository.FinanceTransferRepository financeTransferRepository;

    @Autowired
    protected com.blistra.finance.repository.FinanceTransactionRepository financeTransactionRepository;

    @Autowired
    protected com.blistra.finance.repository.CategoryRepository categoryRepository;

    @Autowired
    protected com.blistra.finance.repository.AccountRepository accountRepository;

    @BeforeEach
    void cleanDatabase() {
        financeTransferRepository.deleteAll();
        financeTransactionRepository.deleteAll();
        categoryRepository.deleteAll();
        accountRepository.deleteAll();
        deleteAllUsers();
    }

    protected String registerAndLogin(String email, String password) throws Exception {
        RegisterRequest register = RegisterRequest.builder()
                .email(email)
                .password(password)
                .build();
        mockMvc.perform(post(REGISTER_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(register)))
                .andExpect(status().isCreated());
        return login(email, password);
    }

    protected String login(String email, String password) throws Exception {
        LoginRequest login = LoginRequest.builder()
                .email(email)
                .password(password)
                .build();
        MvcResult result = mockMvc.perform(post(LOGIN_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(login)))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("token")
                .asText();
    }

    protected String createAccount(String token, String name, String type, String currency,
                                   String openingBalance) throws Exception {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("name", name);
        body.put("type", type);
        body.put("currency", currency);
        body.put("openingBalance", openingBalance);
        return postAccount(token, body, false);
    }

    protected String createAccount(String token, ObjectNode body) throws Exception {
        return postAccount(token, body, false);
    }

    protected String createAccountAndExpectStatus(String token, ObjectNode body, int statusCode) throws Exception {
        return postAccount(token, body, true);
    }

    private String postAccount(String token, ObjectNode body, boolean expectError) throws Exception {
        var action = mockMvc.perform(post(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body)));
        if (expectError) {
            action.andReturn();
            return null;
        }
        MvcResult result = action.andExpect(status().isCreated()).andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("id").asText();
    }

    protected String createCategory(String token, String name, String type) throws Exception {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("name", name);
        body.put("type", type);
        MvcResult result = mockMvc.perform(post(CATEGORIES_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("id").asText();
    }

    protected String createTransaction(String token, String accountId, String categoryId,
                                       String type, String amount, String occurredAt) throws Exception {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("accountId", accountId);
        body.put("categoryId", categoryId);
        body.put("type", type);
        body.put("amount", amount);
        if (occurredAt != null) {
            body.put("occurredAt", occurredAt);
        }
        MvcResult result = mockMvc.perform(post(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("id").asText();
    }

    protected String createTransfer(String token, String sourceAccountId, String destinationAccountId,
                                    String amount, String transferredAt) throws Exception {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("sourceAccountId", sourceAccountId);
        body.put("destinationAccountId", destinationAccountId);
        body.put("amount", amount);
        if (transferredAt != null) {
            body.put("transferredAt", transferredAt);
        }
        MvcResult result = mockMvc.perform(post(TRANSFERS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body)))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("id").asText();
    }
}