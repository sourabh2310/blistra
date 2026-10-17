package com.blistra.finance;

import tools.jackson.databind.JsonNode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;

import java.time.LocalDate;
import java.time.YearMonth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end flow: find a friend by username, split expenses, track
 * balances and spending, settle up.
 */
class FinanceSplitIntegrationTest extends FinanceTestSupport {

    private static final String FRIENDS = "/api/v1/finance/friends";
    private static final String EXPENSES = "/api/v1/finance/expenses";
    private static final String SETTLEMENTS = "/api/v1/finance/settlements";
    private static final String OVERVIEW = "/api/v1/finance/overview";
    private static final String BUDGETS = "/api/v1/finance/budgets";

    private String alice;
    private String bob;
    private String carol;
    private String aliceId;
    private String bobId;

    @BeforeEach
    void users() throws Exception {
        alice = registerAndLogin("alice@example.com", "Password123!");
        bob = registerAndLogin("bob@example.com", "Password123!");
        carol = registerAndLogin("carol@example.com", "Password123!");
        aliceId = userRepository.findByEmail("alice@example.com").orElseThrow().getId().toString();
        bobId = userRepository.findByEmail("bob@example.com").orElseThrow().getId().toString();
    }

    // ------------------------------------------------------------------ helpers

    private ResultActions call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,
                               String token, String body) throws Exception {
        req.header("Authorization", "Bearer " + token);
        if (body != null) {
            req.contentType(MediaType.APPLICATION_JSON).content(body);
        }
        return mockMvc.perform(req);
    }

    private JsonNode json(ResultActions actions, int expectedStatus) throws Exception {
        MvcResult result = actions.andExpect(status().is(expectedStatus)).andReturn();
        String content = result.getResponse().getContentAsString();
        return content.isEmpty() ? null : jsonMapper.readTree(content);
    }

    private void befriendAliceAndBob() throws Exception {
        json(call(post(FRIENDS), alice, "{\"username\":\"bob\"}"), 201);
        JsonNode bobView = json(call(get(FRIENDS), bob, null), 200);
        String requestId = bobView.get("incoming").get(0).get("id").asText();
        json(call(post(FRIENDS + "/requests/" + requestId + "/accept"), bob, null), 204);
    }

    private String splitEqually(String token, String amount, String... userIds) throws Exception {
        StringBuilder participants = new StringBuilder();
        for (String id : userIds) {
            if (!participants.isEmpty()) {
                participants.append(',');
            }
            participants.append("{\"userId\":\"").append(id).append("\"}");
        }
        String body = "{\"description\":\"Dinner\",\"category\":\"FOOD\",\"amount\":\"" + amount
                + "\",\"currency\":\"INR\",\"participants\":[" + participants + "]}";
        return json(call(post(EXPENSES), token, body), 201).get("id").asText();
    }

    private String balanceWith(String token, String friendId) throws Exception {
        JsonNode friends = json(call(get(FRIENDS), token, null), 200).get("friends");
        for (JsonNode f : friends) {
            if (f.get("user").get("id").asText().equals(friendId)) {
                JsonNode balances = f.get("balances");
                return balances.isEmpty() ? "0" : balances.get(0).get("amount").asText();
            }
        }
        return null;
    }

    // ------------------------------------------------------------------ tests

    @Test
    void personalExpenseNeedsNoSetupAndIsTracked() throws Exception {
        JsonNode created = json(call(post(EXPENSES), alice,
                "{\"description\":\"Coffee\",\"category\":\"FOOD\",\"amount\":\"120\",\"currency\":\"INR\"}"), 201);
        assertThat(created.get("splitType").asText()).isEqualTo("NONE");
        assertThat(created.get("myShare").asText()).isEqualTo("120.0000");
        assertThat(created.get("myBalance").asText()).isEqualTo("0.0000");
        assertThat(created.get("editable").asBoolean()).isTrue();
        assertThat(created.get("spentOn").asText()).isNotBlank();

        JsonNode overview = json(call(get(OVERVIEW), alice, null), 200);
        JsonNode inr = overview.get("currencies").get(0);
        assertThat(inr.get("currency").asText()).isEqualTo("INR");
        assertThat(inr.get("spent").asText()).isEqualTo("120.0000");
        assertThat(inr.get("byCategory").get(0).get("category").asText()).isEqualTo("FOOD");

        JsonNode list = json(call(get(EXPENSES).param("q", "coff"), alice, null), 200);
        assertThat(list.get("totalElements").asInt()).isEqualTo(1);
        // Strangers can't see it.
        json(call(get(EXPENSES + "/" + created.get("id").asText()), carol, null), 404);
    }

    @Test
    void friendRequestsWorkByUsername() throws Exception {
        JsonNode sent = json(call(post(FRIENDS), alice, "{\"username\":\"@Bob\"}"), 201);
        assertThat(sent.get("status").asText()).isEqualTo("PENDING");
        assertThat(sent.get("user").get("username").asText()).isEqualTo("bob");

        json(call(post(FRIENDS), alice, "{\"username\":\"bob\"}"), 409);
        json(call(post(FRIENDS), alice, "{\"username\":\"alice\"}"), 400);
        json(call(post(FRIENDS), alice, "{\"username\":\"nobody_here\"}"), 404);

        JsonNode aliceView = json(call(get(FRIENDS), alice, null), 200);
        assertThat(aliceView.get("outgoing")).hasSize(1);
        assertThat(aliceView.get("friends")).isEmpty();

        // Bob adding Alice back accepts her pending request.
        JsonNode back = json(call(post(FRIENDS), bob, "{\"username\":\"alice\"}"), 201);
        assertThat(back.get("status").asText()).isEqualTo("ACCEPTED");
        JsonNode friends = json(call(get(FRIENDS), alice, null), 200).get("friends");
        assertThat(friends).hasSize(1);
        assertThat(friends.get(0).get("friend").asBoolean()).isTrue();

        // Carol declines nothing she wasn't sent.
        String carolRequest = json(call(post(FRIENDS), carol, "{\"username\":\"alice\"}"), 201)
                .get("status").asText();
        assertThat(carolRequest).isEqualTo("PENDING");
        String incomingId = json(call(get(FRIENDS), alice, null), 200).get("incoming").get(0).get("id").asText();
        json(call(delete(FRIENDS + "/requests/" + incomingId), alice, null), 204);
        assertThat(json(call(get(FRIENDS), carol, null), 200).get("outgoing")).isEmpty();
    }

    @Test
    void cannotSplitWithSomeoneWhoIsNotAnAcceptedFriend() throws Exception {
        json(call(post(FRIENDS), alice, "{\"username\":\"bob\"}"), 201);
        String body = "{\"description\":\"Taxi\",\"category\":\"TRANSPORT\",\"amount\":\"100\",\"currency\":\"INR\","
                + "\"participants\":[{\"userId\":\"" + aliceId + "\"},{\"userId\":\"" + bobId + "\"}]}";
        json(call(post(EXPENSES), alice, body), 400);
    }

    @Test
    void splitTrackSettleFlow() throws Exception {
        befriendAliceAndBob();
        String expenseId = splitEqually(alice, "300", aliceId, bobId);

        JsonNode asBob = json(call(get(EXPENSES + "/" + expenseId), bob, null), 200);
        assertThat(asBob.get("myShare").asText()).isEqualTo("150.0000");
        assertThat(asBob.get("myBalance").asText()).isEqualTo("-150.0000");
        assertThat(asBob.get("editable").asBoolean()).isFalse();
        assertThat(asBob.get("paidBy").get("username").asText()).isEqualTo("alice");

        assertThat(balanceWith(alice, bobId)).isEqualTo("150.0000");
        assertThat(balanceWith(bob, aliceId)).isEqualTo("-150.0000");

        JsonNode aliceOverview = json(call(get(OVERVIEW), alice, null), 200);
        assertThat(aliceOverview.get("currencies").get(0).get("spent").asText()).isEqualTo("150.0000");
        assertThat(aliceOverview.get("currencies").get(0).get("paid").asText()).isEqualTo("300.0000");
        assertThat(aliceOverview.get("owedToYou").get(0).get("amount").asText()).isEqualTo("150.0000");
        JsonNode bobOverview = json(call(get(OVERVIEW), bob, null), 200);
        assertThat(bobOverview.get("youOwe").get(0).get("amount").asText()).isEqualTo("150.0000");
        assertThat(bobOverview.get("currencies").get(0).get("spent").asText()).isEqualTo("150.0000");

        // Bob can't change Alice's expense.
        json(call(delete(EXPENSES + "/" + expenseId), bob, null), 400);

        // Partial then full repayment.
        JsonNode firstPayment = json(call(post(SETTLEMENTS), bob, "{\"friendId\":\"" + aliceId
                + "\",\"direction\":\"I_PAID\",\"amount\":\"100\",\"currency\":\"INR\"}"), 201);
        assertThat(firstPayment.get("status").asText()).isEqualTo("PENDING");
        assertThat(balanceWith(alice, bobId)).isEqualTo("150.0000");
        json(call(post(SETTLEMENTS + "/" + firstPayment.get("id").asText() + "/confirm"), alice, null), 200);
        assertThat(balanceWith(alice, bobId)).isEqualTo("50.0000");
        JsonNode secondPayment = json(call(post(SETTLEMENTS), alice, "{\"friendId\":\"" + bobId
                + "\",\"direction\":\"THEY_PAID\",\"amount\":\"50\",\"currency\":\"INR\"}"), 201);
        json(call(post(SETTLEMENTS + "/" + secondPayment.get("id").asText() + "/confirm"), bob, null), 200);
        assertThat(balanceWith(alice, bobId)).isEqualTo("0");

        JsonNode detail = json(call(get(FRIENDS + "/" + bobId), alice, null), 200);
        assertThat(detail.get("expenses")).hasSize(1);
        assertThat(detail.get("settlements")).hasSize(2);
        assertThat(detail.get("friend").get("balances")).isEmpty();
    }

    @Test
    void historicalRecordedPaymentKeepsEffectWithoutClaimingConfirmation() throws Exception {
        befriendAliceAndBob();splitEqually(alice,"300",aliceId,bobId);
        var id=java.util.UUID.randomUUID();
        jdbcTemplate.update("""
            INSERT INTO finance_settlements(id,created_by,payer_id,payee_id,amount,currency,settled_on,status)
            VALUES (?,?,?,?,100,'INR',CURRENT_DATE,'LEGACY_RECORDED')
            """,id,java.util.UUID.fromString(bobId),java.util.UUID.fromString(bobId),java.util.UUID.fromString(aliceId));
        assertThat(balanceWith(alice,bobId)).isEqualTo("50.0000");
        var records=json(call(get(SETTLEMENTS),alice,null),200);
        assertThat(records.get(0).get("status").asText()).isEqualTo("LEGACY_RECORDED");
        assertThat(records.get(0).get("editable").asBoolean()).isFalse();
        json(call(delete(SETTLEMENTS+"/"+id),bob,null),400);
        json(call(post(SETTLEMENTS+"/"+id+"/confirm"),alice,null),409);
    }

    @Test
    void friendCanPayAndCreatorCanEditParticipants() throws Exception {
        befriendAliceAndBob();
        // Bob paid 90 for Alice alone: Alice owes all of it.
        String body = "{\"description\":\"Tickets\",\"category\":\"ENTERTAINMENT\",\"amount\":\"90\","
                + "\"currency\":\"INR\",\"paidBy\":\"" + bobId + "\",\"splitType\":\"EXACT\","
                + "\"participants\":[{\"userId\":\"" + aliceId + "\",\"value\":\"90\"}]}";
        JsonNode created = json(call(post(EXPENSES), alice, body), 201);
        assertThat(created.get("myBalance").asText()).isEqualTo("-90.0000");
        assertThat(balanceWith(alice, bobId)).isEqualTo("-90.0000");

        // Edit to a 2:1 shares split, keeping the same people.
        String edit = "{\"description\":\"Tickets\",\"category\":\"ENTERTAINMENT\",\"amount\":\"90\","
                + "\"currency\":\"INR\",\"paidBy\":\"" + bobId + "\",\"splitType\":\"SHARES\","
                + "\"participants\":[{\"userId\":\"" + aliceId + "\",\"value\":\"2\"},"
                + "{\"userId\":\"" + bobId + "\",\"value\":\"1\"}]}";
        JsonNode updated = json(call(put(EXPENSES + "/" + created.get("id").asText()), alice, edit), 200);
        assertThat(updated.get("myShare").asText()).isEqualTo("60.0000");
        assertThat(updated.get("shares")).hasSize(2);
        assertThat(balanceWith(alice, bobId)).isEqualTo("-60.0000");
    }

    @Test
    void rejectsBadSplits() throws Exception {
        befriendAliceAndBob();
        String mismatch = "{\"description\":\"Hotel\",\"category\":\"TRAVEL\",\"amount\":\"100\",\"currency\":\"INR\","
                + "\"splitType\":\"EXACT\",\"participants\":[{\"userId\":\"" + aliceId + "\",\"value\":\"10\"},"
                + "{\"userId\":\"" + bobId + "\",\"value\":\"10\"}]}";
        json(call(post(EXPENSES), alice, mismatch), 400);
        // An expense between Bob and nobody else is not Alice's to add.
        String notMine = "{\"description\":\"Gift\",\"category\":\"GIFTS\",\"amount\":\"100\",\"currency\":\"INR\","
                + "\"paidBy\":\"" + bobId + "\",\"participants\":[{\"userId\":\"" + bobId + "\"}]}";
        json(call(post(EXPENSES), alice, notMine), 400);
        json(call(post(EXPENSES), alice,
                "{\"description\":\"Zero\",\"category\":\"OTHER\",\"amount\":\"0\",\"currency\":\"INR\"}"), 400);
    }

    @Test
    void unfriendingKeepsAnOpenBalanceVisible() throws Exception {
        befriendAliceAndBob();
        splitEqually(alice, "100", aliceId, bobId);
        json(call(delete(FRIENDS + "/" + bobId), alice, null), 204);

        JsonNode friends = json(call(get(FRIENDS), alice, null), 200).get("friends");
        assertThat(friends).hasSize(1);
        assertThat(friends.get(0).get("friend").asBoolean()).isFalse();
        assertThat(friends.get(0).get("balances").get(0).get("amount").asText()).isEqualTo("50.0000");
        // Still settleable.
        json(call(post(SETTLEMENTS), alice, "{\"friendId\":\"" + bobId
                + "\",\"direction\":\"THEY_PAID\",\"amount\":\"50\",\"currency\":\"INR\"}"), 201);
        // But no new shared expenses.
        String body = "{\"description\":\"Snacks\",\"category\":\"FOOD\",\"amount\":\"10\",\"currency\":\"INR\","
                + "\"participants\":[{\"userId\":\"" + aliceId + "\"},{\"userId\":\"" + bobId + "\"}]}";
        json(call(post(EXPENSES), alice, body), 400);
    }

    @Test
    void budgetsTrackMonthlySpending() throws Exception {
        json(call(post(EXPENSES), alice,
                "{\"description\":\"Groceries\",\"category\":\"GROCERIES\",\"amount\":\"400\",\"currency\":\"INR\"}"),
                201);
        json(call(put(BUDGETS), alice, "{\"currency\":\"INR\",\"monthlyLimit\":\"1000\"}"), 200);
        JsonNode budget = json(call(put(BUDGETS), alice,
                "{\"category\":\"GROCERIES\",\"currency\":\"INR\",\"monthlyLimit\":\"300\"}"), 200);
        assertThat(budget.get("spentThisMonth").asText()).isEqualTo("400.0000");
        // Upsert replaces the limit rather than duplicating.
        json(call(put(BUDGETS), alice, "{\"currency\":\"INR\",\"monthlyLimit\":\"2000\"}"), 200);

        JsonNode budgets = json(call(get(BUDGETS), alice, null), 200);
        assertThat(budgets).hasSize(2);
        JsonNode overview = json(call(get(OVERVIEW).param("month", YearMonth.now().toString()), alice, null), 200);
        assertThat(overview.get("currencies").get(0).get("budgets")).hasSize(2);

        json(call(delete(BUDGETS + "/" + budget.get("id").asText()), bob, null), 404);
        json(call(delete(BUDGETS + "/" + budget.get("id").asText()), alice, null), 204);
    }

    @Test
    void listFiltersByFriendCategoryAndDate() throws Exception {
        befriendAliceAndBob();
        splitEqually(alice, "60", aliceId, bobId);
        json(call(post(EXPENSES), alice, "{\"description\":\"Old fuel\",\"category\":\"FUEL\",\"amount\":\"50\","
                + "\"currency\":\"INR\",\"spentOn\":\"" + LocalDate.now().minusMonths(2) + "\"}"), 201);

        assertThat(json(call(get(EXPENSES).param("friendId", bobId), alice, null), 200)
                .get("totalElements").asInt()).isEqualTo(1);
        assertThat(json(call(get(EXPENSES).param("category", "FUEL"), alice, null), 200)
                .get("totalElements").asInt()).isEqualTo(1);
        assertThat(json(call(get(EXPENSES).param("from", LocalDate.now().withDayOfMonth(1).toString()), alice, null),
                200).get("totalElements").asInt()).isEqualTo(1);
        // Bob sees the shared one only.
        assertThat(json(call(get(EXPENSES), bob, null), 200).get("totalElements").asInt()).isEqualTo(1);
    }
}
