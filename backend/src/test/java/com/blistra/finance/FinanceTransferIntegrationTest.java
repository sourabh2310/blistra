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

class FinanceTransferIntegrationTest extends FinanceTestSupport {

    @Test
    void transfersMoneyBetweenOwnAccounts() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");

        createTransfer(token, checking, savings, "300.0000", "2026-09-03");

        mockMvc.perform(get(ACCOUNTS_URL + "/" + checking)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("700.0000"));

        mockMvc.perform(get(ACCOUNTS_URL + "/" + savings)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("800.0000"));
    }

    @Test
    void transferDoesNotChangeTotalNetWorth() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");

        createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        // spent 30 of checking -> total after transfer should be 1470 (no double count).
        String food = createCategory(token, "Food", "EXPENSE");
        createTransaction(token, checking, food, "EXPENSE", "30.0000", "2026-09-04");

        mockMvc.perform(get(ACCOUNTS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.name == 'Checking')].balance").value("870.0000"))
                .andExpect(jsonPath("$[?(@.name == 'Savings')].balance").value("600.0000"));
        // NOTE: transfer does NOT create any expense/income so net worth is 1500 - 30 = 1470.
        mockMvc.perform(get(SUMMARY_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currencies[0].income").value("0.0000"))
                .andExpect(jsonPath("$.currencies[0].expense").value("30.0000"));
    }

    @Test
    void rejectsSameAccountAndCrossCurrencyTransfers() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String usd1 = createAccount(token, "USD One", "BANK", "USD", "1000.0000");
        String usd2 = createAccount(token, "USD Two", "BANK", "USD", "500.0000");
        String eur = createAccount(token, "EUR Savings", "SAVINGS", "EUR", "200.0000");

        ObjectNode same = transferBody(usd1, usd1, "10.0000", null);
        mockMvc.perform(post(TRANSFERS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(same)))
                .andExpect(status().isBadRequest());

        ObjectNode crossCurrency = transferBody(usd1, eur, "10.0000", null);
        mockMvc.perform(post(TRANSFERS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(crossCurrency)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cannotTransferFromAnotherUsersAccount() throws Exception {
        String owner = registerAndLogin("owner@example.com", "Password123!");
        String intruder = registerAndLogin("intruder@example.com", "Password123!");

        String ownerAccount = createAccount(owner, "Owner Cash", "CASH", "USD", "100.0000");
        String intruderAccount = createAccount(intruder, "Intruder Cash", "CASH", "USD", "100.0000");

        ObjectNode crossUser = transferBody(ownerAccount, intruderAccount, "10.0000", null);
        mockMvc.perform(post(TRANSFERS_URL)
                .header("Authorization", "Bearer " + intruder)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(crossUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void listsAndRetrievesTransfers() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String transferId = createTransfer(token, checking, savings, "250.0000", "2026-09-03");

        mockMvc.perform(get(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sourceAccountName").value("Checking"))
                .andExpect(jsonPath("$.destinationAccountName").value("Savings"))
                .andExpect(jsonPath("$.amount").value("250.0000"));

        mockMvc.perform(get(TRANSFERS_URL)
                .header("Authorization", "Bearer " + token)
                .param("from", "2026-09-01")
                .param("to", "2026-09-30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1));
    }

    @Test
    void updatesAndDeletesTransfer() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String transferId = createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        ObjectNode update = transferBody(checking, savings, "150.0000", "2026-09-05");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").value("150.0000"))
                .andExpect(jsonPath("$.transferredAt").value("2026-09-05"));

        mockMvc.perform(get(ACCOUNTS_URL + "/" + checking)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("850.0000"));

        mockMvc.perform(delete(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(ACCOUNTS_URL + "/" + checking)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("1000.0000"));
    }

    @Test
    void updatesTransferAccounts() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String cash = createAccount(token, "Cash", "CASH", "USD", "200.0000");
        String transferId = createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        ObjectNode update = transferBody(checking, cash, "100.0000", "2026-09-03");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sourceAccountName").value("Checking"))
                .andExpect(jsonPath("$.destinationAccountName").value("Cash"));

        mockMvc.perform(get(ACCOUNTS_URL + "/" + checking)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("900.0000"));

        mockMvc.perform(get(ACCOUNTS_URL + "/" + savings)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("500.0000"));

        mockMvc.perform(get(ACCOUNTS_URL + "/" + cash)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.balance").value("300.0000"));
    }

    @Test
    void cannotUpdateTransferToAnotherUsersAccount() throws Exception {
        String owner = registerAndLogin("owner@example.com", "Password123!");
        String intruder = registerAndLogin("intruder@example.com", "Password123!");

        String ownerChecking = createAccount(owner, "Checking", "BANK", "USD", "1000.0000");
        String ownerSavings = createAccount(owner, "Savings", "SAVINGS", "USD", "500.0000");
        String intruderAccount = createAccount(intruder, "Intruder Cash", "CASH", "USD", "100.0000");
        String transferId = createTransfer(owner, ownerChecking, ownerSavings, "100.0000", "2026-09-03");

        ObjectNode update = transferBody(ownerChecking, intruderAccount, "100.0000", "2026-09-03");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + owner)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isNotFound());
    }

    @Test
    void cannotUpdateTransferToArchivedAccount() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String cash = createAccount(token, "Cash", "CASH", "USD", "200.0000");
        String transferId = createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        mockMvc.perform(delete(ACCOUNTS_URL + "/" + cash)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        ObjectNode update = transferBody(checking, cash, "100.0000", "2026-09-03");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cannotUpdateTransferToSameAccount() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String transferId = createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        ObjectNode update = transferBody(checking, checking, "100.0000", "2026-09-03");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cannotUpdateTransferCrossCurrency() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String checking = createAccount(token, "Checking", "BANK", "USD", "1000.0000");
        String savings = createAccount(token, "Savings", "SAVINGS", "USD", "500.0000");
        String eur = createAccount(token, "EUR Account", "SAVINGS", "EUR", "200.0000");
        String transferId = createTransfer(token, checking, savings, "100.0000", "2026-09-03");

        ObjectNode update = transferBody(checking, eur, "100.0000", "2026-09-03");
        mockMvc.perform(put(TRANSFERS_URL + "/" + transferId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isBadRequest());
    }

    private ObjectNode transferBody(String source, String destination, String amount, String date) {
        ObjectNode body = jsonMapper.createObjectNode();
        body.put("sourceAccountId", source);
        body.put("destinationAccountId", destination);
        body.put("amount", amount);
        if (date != null) {
            body.put("transferredAt", date);
        }
        return body;
    }
}