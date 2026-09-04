package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.session.service.HumeChatClient;
import com.hackathonyaho.voicejournal.session.service.HumeTokenService;
import com.hackathonyaho.voicejournal.session.service.SessionQueue;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.OptionalInt;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * 동시 접속 대기열 (계약 §2-14).
 *
 * <p><b>트랜잭션을 걸지 않는다</b> — 입장 응답이 실제로 세션을 만들고 커밋까지 가는지를
 * 봐야 한다. 뒷정리는 각 테스트가 한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SessionQueueApiTest {

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired SessionQueue queue;
    @Autowired ObjectMapper objectMapper;

    @MockitoBean HumeTokenService humeTokenService;
    @MockitoBean HumeChatClient humeChatClient;

    private String jwt;

    @BeforeEach
    void setUp() {
        given(humeTokenService.issue())
                .willReturn(new HumeTokenService.Token("hume_at_test", Instant.now().plusSeconds(1800)));
        UUID profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));
        jwt = jwtProvider.issue(profileId).token();
    }

    private void seatsTaken(int active) {
        given(humeChatClient.activeCount(anyInt())).willReturn(OptionalInt.of(active));
    }

    @Test
    @DisplayName("정원이 차면 201이 아니라 202 + 대기 순번이다")
    void fullReturnsTicket() throws Exception {
        seatsTaken(5);

        String body = mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.ticketId").exists())
                .andExpect(jsonPath("$.position").value(1))
                .andExpect(jsonPath("$.pollIntervalSec").value(2))
                // 대기 중에는 세션이 없다 — 자리를 예약해 두지 않는다.
                .andExpect(jsonPath("$.session").value(org.hamcrest.Matchers.nullValue()))
                .andReturn().getResponse().getContentAsString();

        queue.remove(ticketOf(body));
    }

    /** <b>이 응답이 곧 입장권이다.</b> 예약 타이머도, 자리 배정 단계도 없다. */
    @Test
    @DisplayName("자리가 나면 폴링 응답에 세션이 실려 온다 — position 0")
    void pollAdmitsWhenSeatFrees() throws Exception {
        seatsTaken(5);
        UUID ticket = ticketOf(startAndGetBody());

        mvc.perform(get("/api/session/queue/{id}", ticket).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.position").value(1))
                .andExpect(jsonPath("$.session").value(org.hamcrest.Matchers.nullValue()));

        seatsTaken(4);

        mvc.perform(get("/api/session/queue/{id}", ticket).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.position").value(0))
                .andExpect(jsonPath("$.session.sessionId").exists())
                .andExpect(jsonPath("$.session.humeAccessToken").value("hume_at_test"))
                .andExpect(jsonPath("$.session.humeConfigId").value("cfg_test"));

        // 받아 간 티켓은 줄에서 사라진다 — 두 번 입장할 수 없다.
        mvc.perform(get("/api/session/queue/{id}", ticket).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("QUEUE_TICKET_NOT_FOUND"));
    }

    @Test
    @DisplayName("남의 티켓으로는 순번도 못 본다 — 그 응답이 입장권이기 때문이다")
    void otherProfileCannotPoll() throws Exception {
        seatsTaken(5);
        UUID ticket = ticketOf(startAndGetBody());

        UUID other = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(other));

        mvc.perform(get("/api/session/queue/{id}", ticket)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwtProvider.issue(other).token()))
                .andExpect(status().isNotFound());

        queue.remove(ticket);
    }

    @Test
    @DisplayName("한 사람에게 티켓 하나다 — 새로 고쳐도 줄이 늘지 않는다")
    void oneTicketPerProfile() throws Exception {
        seatsTaken(5);
        int before = queue.size();

        UUID first = ticketOf(startAndGetBody());
        UUID again = ticketOf(startAndGetBody());

        assertThat(again).isEqualTo(first);
        assertThat(queue.size()).isEqualTo(before + 1);

        queue.remove(first);
    }

    @Test
    @DisplayName("취소하면 줄에서 빠진다")
    void cancelLeavesQueue() throws Exception {
        seatsTaken(5);
        UUID ticket = ticketOf(startAndGetBody());

        mvc.perform(delete("/api/session/queue/{id}", ticket).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNoContent());

        mvc.perform(get("/api/session/queue/{id}", ticket).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNotFound());
    }

    /**
     * <b>조회가 죽었다고 대화를 막지 않는다.</b> 정원을 넘겨 붙으면 Hume이 E0700으로
     * 거절하고 그건 앱이 처리한다 — 여기서 막으면 Hume이 멀쩡할 때도 아무도 못 쓴다.
     */
    @Test
    @DisplayName("Hume 조회가 실패하면 입장시킨다 (fail-open)")
    void failOpenWhenLookupFails() throws Exception {
        given(humeChatClient.activeCount(anyInt())).willReturn(OptionalInt.empty());

        mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sessionId").exists());
    }

    private String startAndGetBody() throws Exception {
        return mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
    }

    private UUID ticketOf(String body) throws Exception {
        return UUID.fromString(objectMapper.readTree(body).get("ticketId").asText());
    }
}
