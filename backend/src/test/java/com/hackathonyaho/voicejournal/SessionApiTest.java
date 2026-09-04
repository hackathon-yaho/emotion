package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import com.hackathonyaho.voicejournal.session.service.HumeChatClient;
import com.hackathonyaho.voicejournal.session.service.HumeTokenService;
import com.hackathonyaho.voicejournal.session.service.SessionService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Phase 2 통합 — 세션 수명주기.
 *
 * <p><b>Hume만 대역을 쓴다.</b> 토큰 발급은 유료 계정이 필요하고 실제로 부르면 월 할당량을
 * 깎는다. 나머지(DB·필터·정책값)는 전부 실물이다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SessionApiTest {

    private static final String SECRET_HEADER = "X-Internal-Secret";
    private static final String SECRET = "test-internal-secret";

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired VoiceSessionRepository sessionRepository;
    @Autowired SessionService sessionService;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper objectMapper;
    @Autowired EntityManager em;

    @MockitoBean HumeTokenService humeTokenService;
    /** 대역이 없으면 세션 시작마다 실제 api.hume.ai로 나간다. */
    @MockitoBean HumeChatClient humeChatClient;

    private UUID profileId;
    private String jwt;

    @BeforeEach
    void setUp() {
        given(humeTokenService.issue())
                .willReturn(new HumeTokenService.Token("hume_at_test", Instant.now().plusSeconds(1800)));
        // 기본은 자리가 있는 상태다 — 정원이 찬 경우는 그 테스트에서 따로 준다.
        given(humeChatClient.activeCount(anyInt())).willReturn(java.util.OptionalInt.of(0));

        profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));
        jwt = jwtProvider.issue(profileId).token();
    }

    // ── 시작 (F2-01) ────────────────────────────────────────────────

    @Test
    @DisplayName("세션 시작이 계약 §2-4의 정책값을 전부 내려준다 — 앱이 상수로 박지 않아도 된다")
    void startReturnsPolicy() throws Exception {
        mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sessionId").exists())
                .andExpect(jsonPath("$.humeAccessToken").value("hume_at_test"))
                .andExpect(jsonPath("$.humeConfigId").value("cfg_test"))
                .andExpect(jsonPath("$.thresholdMode").value("fixed"))
                .andExpect(jsonPath("$.gapThreshold").value(0.85))
                .andExpect(jsonPath("$.softWrapSec").value(300))
                .andExpect(jsonPath("$.hardCutSec").value(420))
                .andExpect(jsonPath("$.livePollIntervalSec").value(2))
                .andExpect(jsonPath("$.demoMode").value(false));
    }

    @Test
    @DisplayName("다시 시작하면 이전에 열려 있던 세션이 닫힌다 — 열린 세션은 언제나 하나다")
    void startClosesPreviousOpenSession() throws Exception {
        UUID first = startSession();
        UUID second = startSession();

        assertThat(first).isNotEqualTo(second);
        assertThat(sessionRepository.findByProfileIdAndEndedAtIsNull(profileId)).hasSize(1);
        assertThat(sessionRepository.findById(first).orElseThrow().getEndReason()).isEqualTo("timeout");
    }

    /**
     * <b>F3-04의 가드.</b> 5세션 내내 분석이 실패하면(TC-06 반복) 갭이 한 건도 없어
     * {@code avg_gap}이 NULL인데, 세션 수만 보면 그대로 personal로 넘어간다.
     */
    @Test
    @DisplayName("5세션을 넘겨도 평균 갭이 없으면 fixed에 머문다")
    void personalNeedsAvgGap() throws Exception {
        runSql("update user_baseline set session_count = 7, avg_gap = null where profile_id = ?", profileId);

        mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.thresholdMode").value("fixed"));
    }

    @Test
    @DisplayName("평균 갭이 쌓인 5세션 이상은 personal로 전환된다 (TC-07)")
    void personalWhenBaselineReady() throws Exception {
        runSql("update user_baseline set session_count = 5, avg_gap = 0.42 where profile_id = ?", profileId);

        mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.thresholdMode").value("personal"));
    }

    @Test
    @DisplayName("Hume 토큰 발급이 실패하면 503이고, 세션도 만들지 않는다")
    void humeFailureBlocksStart() throws Exception {
        willThrow(new BusinessException(ErrorCode.HUME_TOKEN_ISSUE_FAILED, "boom"))
                .given(humeTokenService).issue();

        mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("HUME_TOKEN_ISSUE_FAILED"));

        assertThat(sessionRepository.findByProfileIdAndEndedAtIsNull(profileId)).isEmpty();
    }

    // ── 종료 (F2-05) ────────────────────────────────────────────────

    @Test
    @DisplayName("종료가 세션을 닫고 baseline의 세션 수를 올린다 — F3-05를 잘라도 남는 동작이다")
    void endRecordsAndCounts() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"endReason\":\"user_end\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turnCount").value(0))
                .andExpect(jsonPath("$.summary").doesNotExist())
                .andExpect(jsonPath("$.gapAvg").doesNotExist());

        assertThat(baselineRepository.findById(profileId).orElseThrow().getSessionCount()).isEqualTo(1);
    }

    /** 앱이 종료를 재시도하는 것은 정상이다 — 그때 404를 주면 방금 한 대화가 사라진 것으로 보인다. */
    @Test
    @DisplayName("이미 닫힌 세션을 다시 종료해도 200이고 세션 수가 두 번 늘지 않는다")
    void endIsIdempotent() throws Exception {
        UUID sessionId = startSession();
        endSession(sessionId);
        endSession(sessionId);

        assertThat(baselineRepository.findById(profileId).orElseThrow().getSessionCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("남의 세션은 종료할 수 없다")
    void endForbidsOtherProfile() throws Exception {
        UUID sessionId = startSession();
        String otherJwt = jwtProvider.issue(profileRepository.save(Profile.create()).getId()).token();

        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherJwt))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("스케줄러 전용 endReason은 앱이 보낼 수 없다")
    void endRejectsInternalReason() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"endReason\":\"timeout\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    // ── 내부 API (계약 §3-1·§3-4) ────────────────────────────────────

    @Test
    @DisplayName("공유 시크릿이 없거나 틀리면 401이다 — JWT로는 통과하지 못한다")
    void internalNeedsSharedSecret() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(get("/internal/sessions/{id}", sessionId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INTERNAL_AUTH_FAILED"));

        mvc.perform(get("/internal/sessions/{id}", sessionId).header(SECRET_HEADER, "wrong"))
                .andExpect(status().isUnauthorized());

        mvc.perform(get("/internal/sessions/{id}", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("세션 컨텍스트가 임계값 스냅샷과 lastTurnIndex를 준다")
    void internalReturnsContext() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(get("/internal/sessions/{id}", sessionId).header(SECRET_HEADER, SECRET))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("open"))
                .andExpect(jsonPath("$.usedSec").value(0))
                .andExpect(jsonPath("$.lastTurnIndex").value(0))
                .andExpect(jsonPath("$.gapThreshold").value(0.85))
                .andExpect(jsonPath("$.hardCutSec").value(420))
                .andExpect(jsonPath("$.recentObservations").isEmpty());
    }

    /** {@code ended}를 401로 바꾸는 판단은 AI서버 몫이다 (계약 §3-4). */
    @Test
    @DisplayName("종료된 세션도 200으로 status만 ended로 준다")
    void internalReturnsEndedSession() throws Exception {
        UUID sessionId = startSession();
        endSession(sessionId);

        mvc.perform(get("/internal/sessions/{id}", sessionId).header(SECRET_HEADER, SECRET))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ended"));
    }

    @Test
    @DisplayName("없는 세션은 404다")
    void internalUnknownSession() throws Exception {
        mvc.perform(get("/internal/sessions/{id}", UUID.randomUUID()).header(SECRET_HEADER, SECRET))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("SESSION_NOT_FOUND"));
    }

    @Test
    @DisplayName("적재된 턴이 있으면 lastTurnIndex가 최대 인덱스다 — 건수가 아니다")
    void lastTurnIndexIsMaxNotCount() throws Exception {
        UUID sessionId = startSession();
        insertTurn(sessionId, 3, Instant.now());
        insertTurn(sessionId, 7, Instant.now());

        mvc.perform(get("/internal/sessions/{id}", sessionId).header(SECRET_HEADER, SECRET))
                .andExpect(jsonPath("$.lastTurnIndex").value(7));
    }

    // ── 이어하기 · 정리 (F2-06 · F2-07) ───────────────────────────────

    @Test
    @DisplayName("GET /api/me가 열린 세션을 알려준다")
    void meExposesOpenSession() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(get("/api/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.openSession.sessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.openSession.remainingSec").value(420))
                .andExpect(jsonPath("$.openSession.resumableUntil").exists());
    }

    /**
     * <b>TC-22.</b> 2분 말하고 앱이 죽은 뒤 5분이 지나도 남는 시간은 잔여분이어야 한다.
     * 벽시계로 재면 여기서 7분이 다 소진돼 이어하기가 409로 막힌다.
     */
    @Test
    @DisplayName("이어하기는 새 7분이 아니라 잔여분을 준다 — 중단 후 흐른 시간은 빼지 않는다")
    void resumeGivesRemainingTime() throws Exception {
        UUID sessionId = startSession();
        Instant startedAt = Instant.now().minus(7, ChronoUnit.MINUTES);
        runSql("update voice_session set started_at = ? where id = ?", java.sql.Timestamp.from(startedAt), sessionId);
        insertTurn(sessionId, 1, startedAt.plusSeconds(120));

        mvc.perform(post("/api/session/{id}/resume", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.remainingSec").value(300))
                .andExpect(jsonPath("$.gapThreshold").value(0.85))
                .andExpect(jsonPath("$.humeConfigId").value("cfg_test"));
    }

    // ── chat_group_id (F2-07, 계약 §2-5-2) ──────────────────────────

    /**
     * <b>이 엔드포인트가 없으면 {@code resumedChatGroupId}가 영원히 null이다.</b>
     * 이어하기 자체는 되지만 이전 대화 맥락이 복원되지 않는다.
     */
    @Test
    @DisplayName("앱이 올린 chatGroupId가 이어하기 응답으로 되돌아온다")
    void chatGroupRoundTrips() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(post("/api/session/{id}/chat-group", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"chatGroupId\":\"cg_2b7f11\"}"))
                .andExpect(status().isNoContent());

        mvc.perform(post("/api/session/{id}/resume", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resumedChatGroupId").value("cg_2b7f11"));
    }

    /** 앱이 재연결마다 보내도 안전해야 한다 — 그래야 재시도를 고민하지 않는다. */
    @Test
    @DisplayName("같은 값을 여러 번 보내도 204이고, 새 값이 오면 새 값이 이긴다")
    void chatGroupIsIdempotent() throws Exception {
        UUID sessionId = startSession();

        postChatGroup(sessionId, "cg_first");
        postChatGroup(sessionId, "cg_first");
        postChatGroup(sessionId, "cg_second");

        mvc.perform(post("/api/session/{id}/resume", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.resumedChatGroupId").value("cg_second"));
    }

    /** 값을 안 보낸 세션은 <b>빈 문자열이 아니라 null</b>이다 (계약 §1-3). */
    @Test
    @DisplayName("chatGroupId를 안 보낸 세션의 resumedChatGroupId는 null이다")
    void resumedChatGroupIdIsNullWhenAbsent() throws Exception {
        UUID sessionId = startSession();

        String body = mvc.perform(post("/api/session/{id}/resume", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.resumedChatGroupId").value(org.hamcrest.Matchers.nullValue()))
                .andReturn().getResponse().getContentAsString();

        // 빈 문자열로 방어할 필요가 없다는 것을 본문으로 못박는다.
        assertThat(body).contains("\"resumedChatGroupId\":null");
    }

    /**
     * 소켓이 열린 직후 보내는 값이라 그 사이에 세션이 닫힐 수 있다. 404로 돌려주면
     * 앱이 재시도해도 영영 성공하지 못한다 — 저장은 해롭지 않으므로 받는다.
     */
    @Test
    @DisplayName("종료된 세션에도 받는다 — 늦게 도착한 값을 404로 튕기지 않는다")
    void chatGroupAcceptedAfterEnd() throws Exception {
        UUID sessionId = startSession();
        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk());

        postChatGroup(sessionId, "cg_late");

        em.flush();
        em.clear();
        assertThat(sessionRepository.findById(sessionId).orElseThrow().getHumeChatGroupId())
                .isEqualTo("cg_late");
    }

    @Test
    @DisplayName("남의 세션에는 못 쓴다 — 403")
    void chatGroupRejectsOtherProfile() throws Exception {
        UUID sessionId = startSession();
        UUID other = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(other));

        mvc.perform(post("/api/session/{id}/chat-group", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwtProvider.issue(other).token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"chatGroupId\":\"cg_stolen\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("빈 chatGroupId는 400이다 — null을 문자열로 덮어쓰지 않는다")
    void chatGroupRejectsBlank() throws Exception {
        UUID sessionId = startSession();

        mvc.perform(post("/api/session/{id}/chat-group", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"chatGroupId\":\"  \"}"))
                .andExpect(status().isBadRequest());
    }

    private void postChatGroup(UUID sessionId, String chatGroupId) throws Exception {
        mvc.perform(post("/api/session/{id}/chat-group", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"chatGroupId\":\"" + chatGroupId + "\"}"))
                .andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("이어하기 창이 지나면 409다")
    void resumeAfterWindow() throws Exception {
        UUID sessionId = startSession();
        backdateStart(sessionId, 31);

        mvc.perform(post("/api/session/{id}/resume", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("SESSION_NOT_RESUMABLE"));
    }

    /**
     * <b>TC-21.</b> 이게 없으면 끊긴 세션이 열린 채 남고 {@code pattern_processed_at}이
     * 영영 NULL이라 그 대화가 관찰 집계에서 통째로 빠진다.
     */
    @Test
    @DisplayName("버려진 세션을 스케줄러가 timeout으로 닫는다 — 창 안의 세션은 건드리지 않는다")
    void schedulerClosesAbandonedSessions() throws Exception {
        UUID stale = startSession();
        backdateStart(stale, 31);
        // 세션 시작 API를 다시 부르면 stale이 그 자리에서 닫혀 스케줄러가 할 일이 없어진다.
        UUID fresh = sessionRepository.save(
                com.hackathonyaho.voicejournal.session.entity.VoiceSession.start(
                        profileId, "fixed", new java.math.BigDecimal("0.85"))).getId();

        assertThat(sessionService.closeAbandonedSessions()).isEqualTo(1);
        assertThat(sessionRepository.findById(stale).orElseThrow().getEndReason()).isEqualTo("timeout");
        assertThat(sessionRepository.findById(fresh).orElseThrow().isOpen()).isTrue();
    }

    // ── 도구 ────────────────────────────────────────────────────────

    private UUID startSession() throws Exception {
        String body = mvc.perform(post("/api/session/start").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        JsonNode json = objectMapper.readTree(body);
        return UUID.fromString(json.get("sessionId").asText());
    }

    private void endSession(UUID sessionId) throws Exception {
        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"endReason\":\"user_end\"}"))
                .andExpect(status().isOk());
    }

    private void backdateStart(UUID sessionId, int minutesAgo) {
        runSql("update voice_session set started_at = ? where id = ?",
                java.sql.Timestamp.from(Instant.now().minus(minutesAgo, ChronoUnit.MINUTES)), sessionId);
    }

    /**
     * <b>JPA와 생 SQL이 같은 트랜잭션을 공유하지만 같은 상태를 보지는 않는다.</b>
     * flush 없이 SQL을 쏘면 아직 INSERT되지 않은 행을 건드려 0건이 갱신되고,
     * clear 없이 다시 읽으면 영속성 컨텍스트의 옛 엔티티가 돌아온다.
     */
    private void runSql(String sql, Object... args) {
        em.flush();
        jdbc.update(sql, args);
        em.clear();
    }

    /** 본문은 Phase 3에서 암호화된다. 여기서는 집계만 보므로 자리표시를 넣는다. */
    private void insertTurn(UUID sessionId, int turnIndex, Instant occurredAt) {
        runSql("""
                        insert into turn_log (session_id, turn_index, role, occurred_at, transcript_enc)
                        values (?, ?, 'user', ?, 'enc-placeholder')
                        """,
                sessionId, turnIndex, java.sql.Timestamp.from(occurredAt));
    }
}
