package com.blistra.planner;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.planner.repository.PlannerEventRepository;
import com.blistra.planner.repository.TaskListRepository;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

public abstract class PlannerTestSupport extends AbstractIntegrationTest {

    protected static final String REGISTER_URL = "/api/v1/auth/register";
    protected static final String LOGIN_URL = "/api/v1/auth/login";
    protected static final String TASKS_URL = "/api/v1/planner/tasks";
    protected static final String LISTS_URL = "/api/v1/planner/lists";
    protected static final String EVENTS_URL = "/api/v1/planner/events";
    protected static final String TODAY_URL = "/api/v1/planner/today";

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JsonMapper jsonMapper;

    @Autowired
    protected UserRepository userRepository;

    @Autowired
    protected TaskRepository taskRepository;

    @Autowired
    protected TaskListRepository taskListRepository;

    @Autowired
    protected PlannerEventRepository eventRepository;

    @BeforeEach
    void cleanDatabase() {
        taskRepository.deleteAll();
        taskListRepository.deleteAll();
        eventRepository.deleteAll();
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

    protected String authHeader(String token) {
        return "Bearer " + token;
    }

    protected JsonNode body(MvcResult result) throws IOException {
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }
}