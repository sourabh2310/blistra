package com.blistra.finance;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import tools.jackson.databind.JsonNode;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class FinanceGroupIntegrationTest extends FinanceTestSupport {
    private static final String GROUPS="/api/v1/finance/groups", PAYMENTS="/api/v1/finance/settlements";
    private String alice,bob,carol,stranger,aliceId,bobId,carolId;
    @BeforeEach void members() throws Exception {
        alice=registerAndLogin("alice@example.com","Password123!");
        bob=registerAndLogin("bob@example.com","Password123!");
        carol=registerAndLogin("carol@example.com","Password123!");
        stranger=registerAndLogin("stranger@example.com","Password123!");
        aliceId=id("alice"); bobId=id("bob"); carolId=id("carol");
    }
    private String id(String name) { return userRepository.findByEmail(name+"@example.com").orElseThrow().getId().toString(); }
    private JsonNode request(MockHttpServletRequestBuilder r,String token,Object body,int expected) throws Exception {
        r.header("Authorization","Bearer "+token);
        if (body!=null) r.contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(body));
        var result=mockMvc.perform(r).andExpect(status().is(expected)).andReturn();
        String text=result.getResponse().getContentAsString();
        return text.isBlank() ? jsonMapper.nullNode() : jsonMapper.readTree(text);
    }
    private String create(String name) throws Exception {
        return request(post(GROUPS),alice,java.util.Map.of("name",name,"currency","INR"),201).get("id").asText();
    }
    private void join(String group,String name,String token) throws Exception {
        request(post(GROUPS+"/"+group+"/members"),alice,java.util.Map.of("username",name),204);
        request(post(GROUPS+"/"+group+"/accept"),token,null,204);
    }
    private String expense(String group) throws Exception {
        return request(post("/api/v1/finance/expenses"),alice,java.util.Map.of(
            "description","Hotel", "category","TRAVEL", "amount","300", "currency","INR",
            "groupId",group,"splitType","EQUAL","participants",java.util.List.of(
                java.util.Map.of("userId",aliceId),java.util.Map.of("userId",bobId),java.util.Map.of("userId",carolId))),201)
            .get("id").asText();
    }
    private String balance(String group,String user) throws Exception {
        var balances=request(get(GROUPS+"/"+group),alice,null,200).get("balances");
        for (var row:balances) if (row.get("userId").asText().equals(user)) return row.get("amount").asText();
        return "0";
    }
    @Test void invitationsAreConsentBoundaryAndThreePeopleCanShare() throws Exception {
        String group=create("Goa trip");
        request(post(GROUPS+"/"+group+"/members"),alice,java.util.Map.of("username","bob"),204);
        request(get(GROUPS+"/"+group),bob,null,404);
        request(get(GROUPS+"/"+group+"/expenses"),bob,null,404);
        request(get("/api/v1/finance/history").param("groupId",group),bob,null,404);
        assertThat(request(get(GROUPS),bob,null,200).get(0).get("membership").asText()).isEqualTo("INVITED");
        request(post(GROUPS+"/"+group+"/accept"),stranger,null,404);
        request(post(GROUPS+"/"+UUID.randomUUID()+"/accept"),bob,null,404);
        request(post(GROUPS+"/"+group+"/accept"),bob,null,204);
        join(group,"carol",carol);
        String expense=expense(group);
        assertThat(balance(group,aliceId)).isEqualTo("200.0000");
        assertThat(balance(group,bobId)).isEqualTo("-100.0000");
        assertThat(balance(group,carolId)).isEqualTo("-100.0000");
        request(get("/api/v1/finance/expenses/"+expense),stranger,null,404);
        request(delete("/api/v1/finance/expenses/"+expense),bob,null,400);
        request(post(GROUPS+"/"+group+"/members"),bob,java.util.Map.of("username","stranger"),400);
        assertThat(request(get("/api/v1/finance/history").param("groupId",group),bob,null,200)).hasSize(1);
    }
    @Test void paymentNeedsOtherParticipantAndCannotCrossTrips() throws Exception {
        String trip=create("Trip one"),other=create("Trip two");
        join(trip,"bob",bob);join(trip,"carol",carol);expense(trip);
        join(other,"bob",bob);join(other,"carol",carol);expense(other);
        var payment=request(post(PAYMENTS),bob,java.util.Map.of("groupId",trip,"friendId",aliceId,
            "direction","I_PAID","amount","100","currency","INR"),201);
        String paymentPath=PAYMENTS+"/"+payment.get("id").asText();
        assertThat(payment.get("status").asText()).isEqualTo("PENDING");
        assertThat(balance(trip,bobId)).isEqualTo("-100.0000");
        request(post(paymentPath+"/confirm"),bob,null,400);
        request(post(paymentPath+"/confirm"),carol,null,404);
        request(post(paymentPath+"/confirm"),stranger,null,404);
        assertThat(request(post(paymentPath+"/confirm"),alice,null,200).get("status").asText()).isEqualTo("CONFIRMED");
        request(post(paymentPath+"/confirm"),alice,null,200); // safe retry
        request(post(paymentPath+"/reject"),alice,null,409);
        request(delete(paymentPath),bob,null,400);
        assertThat(balance(trip,bobId)).isEqualTo("0");
        assertThat(balance(other,bobId)).isEqualTo("-100.0000");
        assertThat(request(get("/api/v1/finance/friends"),alice,null,200).get("friends")).isEmpty();
        var rejected=request(post(PAYMENTS),carol,java.util.Map.of("groupId",trip,"friendId",aliceId,
            "direction","I_PAID","amount","50","currency","INR"),201);
        request(post(PAYMENTS+"/"+rejected.get("id").asText()+"/reject"),alice,null,200);
        assertThat(balance(trip,carolId)).isEqualTo("-100.0000");
    }
    @Test void ownerCanTransferAndLeaveWithoutErasingLedger() throws Exception {
        String group=create("Trip");join(group,"bob",bob);join(group,"carol",carol);expense(group);
        request(delete(GROUPS+"/"+group+"/membership"),alice,null,400);
        request(post(GROUPS+"/"+group+"/owner"),bob,java.util.Map.of("userId",bobId),400);
        request(post(GROUPS+"/"+group+"/owner"),alice,java.util.Map.of("userId",bobId),204);
        request(delete(GROUPS+"/"+group+"/membership"),alice,null,204);
        request(get(GROUPS+"/"+group),alice,null,404);
        assertThat(request(get(GROUPS+"/"+group+"/expenses"),bob,null,200).get("content")).hasSize(1);
    }
    @Test void splitSnapshotsSurviveEditAndDeleteAndHistoryCanBePaged() throws Exception {
        String group=create("History trip");join(group,"bob",bob);join(group,"carol",carol);
        String id=expense(group);
        request(put("/api/v1/finance/expenses/"+id),alice,java.util.Map.of(
            "description","Updated hotel","notes","Do not copy this note into history", "category","TRAVEL",
            "amount","600", "currency","INR","groupId",group,"splitType","EQUAL","participants",java.util.List.of(
                java.util.Map.of("userId",aliceId),java.util.Map.of("userId",bobId))),200);
        request(delete("/api/v1/finance/expenses/"+id),alice,null,204);
        var history=request(get("/api/v1/finance/history").param("groupId",group),bob,null,200);
        assertThat(history).hasSize(3);
        var changed=history.get(1);
        var before=jsonMapper.readTree(changed.get("beforeState").asText());
        var after=jsonMapper.readTree(changed.get("afterState").asText());
        assertThat(before.get("shares")).hasSize(3);
        assertThat(after.get("shares")).hasSize(2);
        assertThat(new java.math.BigDecimal(before.get("amount").asText())).isEqualByComparingTo("300");
        assertThat(new java.math.BigDecimal(after.get("amount").asText())).isEqualByComparingTo("600");
        assertThat(changed.get("actorName").asText()).isNotBlank();
        assertThat(history.toString()).doesNotContain("Updated hotel","Do not copy this note");
        var first=request(get("/api/v1/finance/history").param("groupId",group).param("size","1"),bob,null,200);
        var second=request(get("/api/v1/finance/history").param("groupId",group).param("size","1").param("page","1"),bob,null,200);
        assertThat(first.get(0).get("id")).isNotEqualTo(second.get(0).get("id"));
        request(get("/api/v1/finance/history").param("groupId",group).param("page","1"),stranger,null,404);
    }

    @Test void archivedTripPreservesLedgerAndExportButRejectsNewWrites() throws Exception {
        String group=create("Archive trip");join(group,"bob",bob);join(group,"carol",carol);
        String id=expense(group);
        String payment=request(post(PAYMENTS),bob,java.util.Map.of("groupId",group,"friendId",aliceId,
            "direction","I_PAID","amount","100","currency","INR"),201).get("id").asText();
        request(post(GROUPS+"/"+group+"/archive"),bob,java.util.Map.of("archived",true),400);
        request(post(GROUPS+"/"+group+"/archive"),alice,java.util.Map.of("archived",true),204);
        assertThat(request(get(GROUPS+"/"+group),bob,null,200).get("group").get("archived").asBoolean()).isTrue();
        assertThat(request(get("/api/v1/finance/expenses/"+id),alice,null,200).get("editable").asBoolean()).isFalse();
        request(delete("/api/v1/finance/expenses/"+id),alice,null,400);
        request(post(GROUPS+"/"+group+"/members"),alice,java.util.Map.of("username","stranger"),400);
        request(post(PAYMENTS),bob,java.util.Map.of("groupId",group,"friendId",aliceId,
            "direction","I_PAID","amount","10","currency","INR"),400);
        request(post(PAYMENTS+"/"+payment+"/confirm"),alice,null,200);
        var export=request(get(GROUPS+"/"+group+"/export"),carol,null,200);
        assertThat(export.get("expenses")).hasSize(1);
        assertThat(export.get("payments")).hasSize(1);
        assertThat(export.get("history")).hasSize(3);
        assertThat(export.toString()).doesNotContain("passwordHash","@example.com","Bearer ");
        request(get(GROUPS+"/"+group+"/export"),stranger,null,404);
        request(post(GROUPS+"/"+group+"/archive"),alice,java.util.Map.of("archived",false),204);
        request(delete("/api/v1/finance/expenses/"+id),alice,null,204);
    }

    @Test void groupPaymentsCanBePagedWithoutCrossTripLeakage() throws Exception {
        String group=create("Payment pages");join(group,"bob",bob);
        for (int i=0;i<3;i++) request(post(PAYMENTS),bob,java.util.Map.of("groupId",group,"friendId",aliceId,
            "direction","I_PAID","amount","10","currency","INR"),201);
        var one=request(get(PAYMENTS).param("groupId",group).param("size","1"),bob,null,200);
        var two=request(get(PAYMENTS).param("groupId",group).param("size","1").param("page","1"),bob,null,200);
        assertThat(one).hasSize(1);assertThat(two).hasSize(1);
        assertThat(one.get(0).get("id")).isNotEqualTo(two.get(0).get("id"));
        request(get(PAYMENTS).param("groupId",group).param("page","1"),stranger,null,404);
    }

    @Test void accountDeactivationTransfersSharedGroupAndKeepsOtherMembersLedger() throws Exception {
        String group=create("Shared trip");join(group,"bob",bob);join(group,"carol",carol);expense(group);
        request(post("/api/v1/profile/delete-account"),alice,java.util.Map.of("currentPassword","Password123!"),204);
        assertThat(request(get(GROUPS+"/"+group),bob,null,200).get("group").get("ownerId").asText()).isEqualTo(bobId);
        assertThat(request(get(GROUPS+"/"+group+"/expenses"),bob,null,200).get("content")).hasSize(1);
        request(get(GROUPS+"/"+group),alice,null,401);
    }
}
