package com.blistra.finance;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import tools.jackson.databind.node.ObjectNode;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class FinanceAccountIntegrationTest extends FinanceTestSupport {

    @Test
    void unauthenticatedRequestsAreRejected() throws Exception {
        mockMvc.perform(get(ACCOUNTS_URL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createsAndRetrievesAccount() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Main Wallet", "CASH", "USD", "1000.0000");

        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Main Wallet"))
                .andExpect(jsonPath("$.type").value("CASH"))
                .andExpect(jsonPath("$.currency").value("USD"))
                .andExpect(jsonPath("$.openingBalance").value("1000.0000"))
                .andExpect(jsonPath("$.balance").value("1000.0000"))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void rejectsInvalidAccountPayloads() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");

        ObjectNode badCurrency = jsonMapper.createObjectNode();
        badCurrency.put("name", "Cash");
        badCurrency.put("type", "CASH");
        badCurrency.put("currency", "usd");
        badCurrency.put("openingBalance", "100");
        mockMvc.perform(postAccount(badCurrency, token))
                .andExpect(status().isBadRequest());

        ObjectNode negative = jsonMapper.createObjectNode();
        negative.put("name", "Cash");
        negative.put("type", "CASH");
        negative.put("currency", "USD");
        negative.put("openingBalance", "-5");
        mockMvc.perform(postAccount(negative, token))
                .andExpect(status().isBadRequest());

        ObjectNode missingType = jsonMapper.createObjectNode();
        missingType.put("name", "Cash");
        missingType.put("currency", "USD");
        missingType.put("openingBalance", "100");
        mockMvc.perform(postAccount(missingType, token))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listsAccountsWithDerivedBalances() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        createAccount(token, "Cash", "CASH", "USD", "500.0000");
        createAccount(token, "Savings", "SAVINGS", "EUR", "2000.0000");

        mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].balance").value("500.0000"))
                .andExpect(jsonPath("$[1].balance").value("2000.0000"));
    }

    @Test
    void cannotAccessAnotherUsersAccount() throws Exception {
        String owner = registerAndLogin("owner@example.com", "Password123!");
        String intruder = registerAndLogin("intruder@example.com", "Password123!");

        String accountId = createAccount(owner, "My Cash", "CASH", "USD", "100.0000");

        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());
    }

    @Test
    void updatesOwnAccountButCurrencyIsImmutable() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "100.0000");

        ObjectNode rename = jsonMapper.createObjectNode();
        rename.put("name", "Daily Cash");
        rename.put("type", "WALLET");
        rename.put("currency", "USD");
        rename.put("openingBalance", "150.0000");
        rename.put("notes", "updated");
        mockMvc.perform(put(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(rename)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Daily Cash"))
                .andExpect(jsonPath("$.type").value("WALLET"))
                .andExpect(jsonPath("$.openingBalance").value("150.0000"))
                .andExpect(jsonPath("$.notes").value("updated"));

        ObjectNode changeCurrency = jsonMapper.createObjectNode();
        changeCurrency.put("name", "Daily Cash");
        changeCurrency.put("type", "WALLET");
        changeCurrency.put("currency", "EUR");
        changeCurrency.put("openingBalance", "150.0000");
        mockMvc.perform(put(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(changeCurrency)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void archivesAccountAndBlocksReuse() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "0.0000");
        String categoryId = createCategory(token, "Food", "EXPENSE");

        mockMvc.perform(delete(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(ACCOUNTS_URL + "/" + accountId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));

        ObjectNode tx = jsonMapper.createObjectNode();
        tx.put("accountId", accountId);
        tx.put("categoryId", categoryId);
        tx.put("type", "EXPENSE");
        tx.put("amount", "5.0000");
        mockMvc.perform(postResource(TRANSACTIONS_URL, tx, token))
                .andExpect(status().isBadRequest());
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder postAccount(ObjectNode body,
                                                                                                  String token)
            throws Exception {
        return postResource(ACCOUNTS_URL, body, token);
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder postResource(String url,
                                                                                                   ObjectNode body,
                                                                                                   String token)
            throws Exception {
        return org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post(url)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body));
    }
}