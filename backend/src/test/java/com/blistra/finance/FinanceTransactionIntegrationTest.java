package com.blistra.finance;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import tools.jackson.databind.node.ObjectNode;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class FinanceTransactionIntegrationTest extends FinanceTestSupport {

    @Test
    void createsTransactionAndDerivesBalance() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "1000.0000");
        String incomeCategory = createCategory(token, "Salary", "INCOME");
        String expenseCategory = createCategory(token, "Food", "EXPENSE");

        createTransaction(token, accountId, incomeCategory, "INCOME", "500.0000", "2026-09-01");
        createTransaction(token, accountId, expenseCategory, "EXPENSE", "125.5000", "2026-09-02");

        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("1374.5000"));
    }

    @Test
    void preservesSubCentPrecision() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "42.0000");
        String incomeCategory = createCategory(token, "Interest", "INCOME");

        createTransaction(token, accountId, incomeCategory, "INCOME", "0.0001", "2026-09-01");

        // 42.0000 + 0.0001 => 42.0001: the smallest representable delta must not be lost.
        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("42.0001"));
    }

    @Test
    void rejectsTypePumpingAmountAndScaleViolations() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "0.0000");
        String expenseCategory = createCategory(token, "Food", "EXPENSE");
        String incomeCategory = createCategory(token, "Salary", "INCOME");

        // amount must be positive
        ObjectNode zero = tx(accountId, expenseCategory, "EXPENSE", "0.0000", null);
        mockMvc.perform(post(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(zero)))
                .andExpect(status().isBadRequest());

        // transaction type must match category type
        ObjectNode mismatch = tx(accountId, incomeCategory, "EXPENSE", "10.0000", null);
        mockMvc.perform(post(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(mismatch)))
                .andExpect(status().isBadRequest());

        // over-precise amount rejected
        ObjectNode scale = tx(accountId, expenseCategory, "EXPENSE", "1.00005", null);
        mockMvc.perform(post(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(scale)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listsTransactionsWithFiltersAndPagination() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "0.0000");
        String expenseCategory = createCategory(token, "Food", "EXPENSE");
        String otherCategory = createCategory(token, "Travel", "EXPENSE");

        createTransaction(token, accountId, expenseCategory, "EXPENSE", "10.0000", "2026-09-01");
        createTransaction(token, accountId, expenseCategory, "EXPENSE", "20.0000", "2026-09-05");
        createTransaction(token, accountId, otherCategory, "EXPENSE", "30.0000", "2026-09-10");

        mockMvc.perform(get(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .param("categoryId", expenseCategory)
                .param("from", "2026-09-01")
                .param("to", "2026-09-06"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content[0].amount").value("20.0000"));

        mockMvc.perform(get(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .param("page", "0")
                .param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.totalPages").value(2))
                .andExpect(jsonPath("$.last").value(false));
    }

    @Test
    void cannotAccessAnotherUsersTransaction() throws Exception {
        String owner = registerAndLogin("owner@example.com", "Password123!");
        String intruder = registerAndLogin("intruder@example.com", "Password123!");

        String accountId = createAccount(owner, "Cash", "CASH", "USD", "0.0000");
        String expenseCategory = createCategory(owner, "Food", "EXPENSE");
        String txId = createTransaction(owner, accountId, expenseCategory, "EXPENSE", "5.0000", "2026-09-01");

        mockMvc.perform(get(TRANSACTIONS_URL + "/" + txId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(TRANSACTIONS_URL + "/" + txId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());
    }

    @Test
    void updatesTransactionOwnedByUser() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "0.0000");
        String food = createCategory(token, "Food", "EXPENSE");
        String travel = createCategory(token, "Travel", "EXPENSE");
        String txId = createTransaction(token, accountId, food, "EXPENSE", "5.0000", "2026-09-01");

        ObjectNode update = jsonMapper.createObjectNode();
        update.put("accountId", accountId);
        update.put("categoryId", travel);
        update.put("type", "EXPENSE");
        update.put("amount", "9.5000");
        update.put("description", "renamed");
        update.put("occurredAt", "2026-09-08");

        mockMvc.perform(put(TRANSACTIONS_URL + "/" + txId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.categoryName").value("Travel"))
                .andExpect(jsonPath("$.amount").value("9.5000"))
                .andExpect(jsonPath("$.description").value("renamed"))
                .andExpect(jsonPath("$.occurredAt").value("2026-09-08"));
    }

    @Test
    void deletesTransactionAndRecomputesBalance() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "100.0000");
        String expenseCategory = createCategory(token, "Food", "EXPENSE");
        String txId = createTransaction(token, accountId, expenseCategory, "EXPENSE", "30.0000", "2026-09-01");

        mockMvc.perform(delete(TRANSACTIONS_URL + "/" + txId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("100.0000"));
    }

    private ObjectNode tx(String accountId, String categoryId, String type, String amount, String occurredAt) {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("accountId", accountId);
        body.put("categoryId", categoryId);
        body.put("type", type);
        body.put("amount", amount);
        if (occurredAt != null) {
            body.put("occurredAt", occurredAt);
        }
        return body;
    }
}