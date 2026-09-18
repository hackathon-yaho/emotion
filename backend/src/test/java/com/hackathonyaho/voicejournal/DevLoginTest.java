package com.hackathonyaho.voicejournal;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hackathonyaho.voicejournal.auth.repository.AccountRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** 계약 §2-1-1 — 스위치를 켠 상태. 꺼진 기본값은 {@link DevLoginDisabledTest}. */
@SpringBootTest(properties = "app.dev-login.enabled=true")
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DevLoginTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AccountRepository accountRepository;

    @Test
    @DisplayName("호출마다 새 익명 프로필이고, 받은 JWT로 /api/me가 열리며, account는 생기지 않는다")
    void eachCallIsNewGuest() throws Exception {
        long accountsBefore = accountRepository.count();

        JsonNode first = login();
        JsonNode second = login();

        assertThat(first.get("isNewUser").asBoolean()).isTrue();
        assertThat(first.get("profileId").asText()).isNotEqualTo(second.get("profileId").asText());
        assertThat(accountRepository.count()).isEqualTo(accountsBefore);

        mvc.perform(get("/api/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + first.get("jwt").asText()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.profileId").value(first.get("profileId").asText()))
                .andExpect(jsonPath("$.demoMode").value(false));
    }

    @Test
    @DisplayName("서버 전체 분당 30회를 넘으면 429 TOO_MANY_REQUESTS")
    void rateLimited() throws Exception {
        // 같은 컨텍스트의 다른 테스트가 먼저 몇 번 썼을 수 있다 — 31번 안에 반드시 막히면 된다.
        List<Integer> statuses = new ArrayList<>();
        for (int i = 0; i < 31; i++) {
            statuses.add(mvc.perform(post("/api/auth/dev")).andReturn().getResponse().getStatus());
        }
        assertThat(statuses).contains(200);
        assertThat(statuses.get(30)).isEqualTo(429);

        mvc.perform(post("/api/auth/dev"))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.error.code").value("TOO_MANY_REQUESTS"));
    }

    @Test
    @DisplayName("켜져 있으면 파기를 거절한다 — 둘러보는 중인 기록이 사라진다")
    void purgeRefusedWhileEnabled() throws Exception {
        mvc.perform(post("/internal/dev-profiles/purge").header("X-Internal-Secret", "test-internal-secret"))
                .andExpect(status().isForbidden());
    }

    private JsonNode login() throws Exception {
        String body = mvc.perform(post("/api/auth/dev").contentType("application/json").content("{}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body);
    }
}
