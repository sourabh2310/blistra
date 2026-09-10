package com.blistra.habits;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.habits.domain.HabitFrequency;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.CompletionRequest;
import com.blistra.habits.dto.HabitRequest;
import com.blistra.habits.dto.ScheduleRequest;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.json.JsonMapper;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

public abstract class HabitsTestSupport extends AbstractIntegrationTest {

    protected static final String REGISTER_URL = "/api/v1/auth/register";
    protected static final String LOGIN_URL = "/api/v1/auth/login";
    protected static final String HABITS_URL = "/api/v1/habits";

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JsonMapper jsonMapper;

    @Autowired
    protected UserRepository userRepository;

    @BeforeEach
    void cleanDatabase() {
        userRepository.deleteAll();
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

    protected String createHabit(String token, HabitRequest request) throws Exception {
        MvcResult result = mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    protected String createBooleanHabit(String token, String name) throws Exception {
        return createHabit(token, habitRequest(name, HabitType.BOOLEAN, null, null, null, null));
    }

    protected HabitRequest habitRequest(String name, HabitType type,
                                        BigDecimal targetValue, String targetUnit,
                                        Integer targetMinutes, HabitStatus status) {
        HabitRequest request = HabitRequest.builder()
                .name(name)
                .type(type)
                .status(status)
                .build();
        if (type == HabitType.COUNT) {
            request.setTargetValue(targetValue);
            request.setTargetUnit(targetUnit);
        } else if (type == HabitType.DURATION) {
            request.setTargetMinutes(targetMinutes);
        }
        return request;
    }

    protected void upsertSchedule(String token, String habitId, HabitFrequency frequency, List<DayOfWeek> days) throws Exception {
        ScheduleRequest request = ScheduleRequest.builder()
                .frequency(frequency)
                .daysOfWeek(days)
                .build();
        mockMvc.perform(put(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }

    protected void recordCompletion(String token, String habitId, LocalDate date,
                                    BigDecimal value, Integer durationMinutes) throws Exception {
        CompletionRequest request = CompletionRequest.builder()
                .completedOn(date)
                .value(value)
                .durationMinutes(durationMinutes)
                .build();
        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }
}