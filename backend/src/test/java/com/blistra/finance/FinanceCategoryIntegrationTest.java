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

class FinanceCategoryIntegrationTest extends FinanceTestSupport {

    @Test
    void createsAndRetrievesCategory() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String categoryId = createCategory(token, "Food", "EXPENSE");

        mockMvc.perform(get(CATEGORIES_URL + "/" + categoryId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Food"))
                .andExpect(jsonPath("$.type").value("EXPENSE"))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void rejectsInvalidCategoryPayloads() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");

        ObjectNode missingType = jsonMapper.createObjectNode();
        missingType.put("name", "Food");
        mockMvc.perform(post(CATEGORIES_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(missingType)))
                .andExpect(status().isBadRequest());

        ObjectNode invalidType = jsonMapper.createObjectNode();
        invalidType.put("name", "Food");
        invalidType.put("type", "TRANSFER");
        mockMvc.perform(post(CATEGORIES_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(invalidType)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listsAndUpdatesCategory() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        createCategory(token, "Food", "EXPENSE");
        createCategory(token, "Salary", "INCOME");

        mockMvc.perform(get(CATEGORIES_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));

        String foodId = createCategory(token, "Food", "EXPENSE");
        ObjectNode rename = jsonMapper.createObjectNode();
        rename.put("name", "Groceries");
        rename.put("type", "EXPENSE");
        mockMvc.perform(put(CATEGORIES_URL + "/" + foodId)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(rename)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Groceries"));
    }

    @Test
    void cannotAccessAnotherUsersCategory() throws Exception {
        String owner = registerAndLogin("owner@example.com", "Password123!");
        String intruder = registerAndLogin("intruder@example.com", "Password123!");

        String categoryId = createCategory(owner, "Food", "EXPENSE");

        mockMvc.perform(get(CATEGORIES_URL + "/" + categoryId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(CATEGORIES_URL + "/" + categoryId)
                .header("Authorization", "Bearer " + intruder))
                .andExpect(status().isNotFound());
    }

    @Test
    void archivesCategoryAndBlocksReuse() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "0.0000");
        String categoryId = createCategory(token, "Food", "EXPENSE");

        mockMvc.perform(delete(CATEGORIES_URL + "/" + categoryId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(CATEGORIES_URL + "/" + categoryId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));

        ObjectNode tx = jsonMapper.createObjectNode();
        tx.put("accountId", accountId);
        tx.put("categoryId", categoryId);
        tx.put("type", "EXPENSE");
        tx.put("amount", "5.0000");
        mockMvc.perform(post(TRANSACTIONS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(tx)))
                .andExpect(status().isBadRequest());
    }
}