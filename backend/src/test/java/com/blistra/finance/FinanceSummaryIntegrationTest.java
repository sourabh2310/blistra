package com.blistra.finance;

import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class FinanceSummaryIntegrationTest extends FinanceTestSupport {

    @Test
    void summarizesIncomeAndExpenseForDefaultCurrentMonth() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "100.0000");
        createAccount(token, "EUR", "CASH", "EUR", "50.0000");

        String salary = createCategory(token, "Salary", "INCOME");
        String food = createCategory(token, "Food", "EXPENSE");

        createTransaction(token, accountId, salary, "INCOME", "1000.0000", "2026-09-01");
        createTransaction(token, accountId, salary, "INCOME", "250.5000", "2026-09-15");
        createTransaction(token, accountId, food, "EXPENSE", "120.7500", "2026-09-20");

        mockMvc.perform(get(SUMMARY_URL)
                .header("Authorization", "Bearer " + token)
                .param("from", "2026-09-01")
                .param("to", "2026-09-30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currencies[0].currency").value("USD"))
                .andExpect(jsonPath("$.currencies[0].income").value("1250.5000"))
                .andExpect(jsonPath("$.currencies[0].expense").value("120.7500"))
                .andExpect(jsonPath("$.currencies[0].net").value("1129.7500"))
                .andExpect(jsonPath("$.currencies[0].spendingByCategory[0].categoryName").value("Food"))
                .andExpect(jsonPath("$.currencies[0].spendingByCategory[0].amount").value("120.7500"));
    }

    @Test
    void respectsDateRangeBoundaries() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "100.0000");
        String salary = createCategory(token, "Salary", "INCOME");
        String food = createCategory(token, "Food", "EXPENSE");

        createTransaction(token, accountId, salary, "INCOME", "10.0000", "2026-08-20");
        createTransaction(token, accountId, salary, "INCOME", "20.0000", "2026-09-02");
        createTransaction(token, accountId, food, "EXPENSE", "30.0000", "2026-09-10");

        mockMvc.perform(get(SUMMARY_URL)
                .header("Authorization", "Bearer " + token)
                .param("from", "2026-09-01")
                .param("to", "2026-09-30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currencies[0].income").value("20.0000"))
                .andExpect(jsonPath("$.currencies[0].expense").value("30.0000"));
    }

    @Test
    void keepsMultiCurrencySectionsSeparate() throws Exception {
        String token = registerAndLogin("owner@example.com", "Password123!");
        String usd = createAccount(token, "USD", "BANK", "USD", "100.0000");
        String eur = createAccount(token, "EUR", "BANK", "EUR", "100.0000");

        String usdSalary = createCategory(token, "Sal", "INCOME");
        String eurSalary = createCategory(token, "SalEUR", "INCOME");

        createTransaction(token, usd, usdSalary, "INCOME", "999.0000", "2026-09-05");
        createTransaction(token, eur, eurSalary, "INCOME", "333.5000", "2026-09-05");

        mockMvc.perform(get(SUMMARY_URL)
                .header("Authorization", "Bearer " + token)
                .param("from", "2026-09-01")
                .param("to", "2026-09-30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currencies.length()").value(2))
                .andExpect(jsonPath("$.currencies[0].currency").value("EUR"))
                .andExpect(jsonPath("$.currencies[0].income").value("333.5000"))
                .andExpect(jsonPath("$.currencies[1].currency").value("USD"))
                .andExpect(jsonPath("$.currencies[1].income").value("999.0000"));
    }

    @Test
    void requiresAuthentication() throws Exception {
        mockMvc.perform(get(SUMMARY_URL))
                .andExpect(status().isUnauthorized());
    }
}