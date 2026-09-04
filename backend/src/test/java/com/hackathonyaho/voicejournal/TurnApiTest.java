package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.common.global.SessionRef;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import com.hackathonyaho.voicejournal.turn.repository.TurnLogRepository;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Phase 3 통합 — 턴 적재 · 암호화 · 대화 중 신호. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class TurnApiTest {

    private static final String SECRET_HEADER = "X-Internal-Secret";
    private static final String SECRET = "test-internal-secret";
    private static final String PLAINTEXT = "오늘 회의가 세 개나 있었는데 다 괜찮았어요";

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired VoiceSessionRepository sessionRepository;
    @Autowired TurnLogRepository turnLogRepository;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager em;

    private UUID profileId;
    private UUID sessionId;
    private String jwt;

    @BeforeEach
    void setUp() {
        profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));
        sessionId = sessionRepository.save(
                VoiceSession.start(profileId, "fixed", new BigDecimal("0.85"))).getId();
        jwt = jwtProvider.issue(profileId).token();
    }

    // ── 적재 (F5-01) ────────────────────────────────────────────────

    @Test
    @DisplayName("턴이 202로 적재되고 태그가 같이 저장된다")
    void ingestStoresTurnAndTags() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", PLAINTEXT, "0.70", "-0.62", "1.32", true,
                List.of("회의"), false);

        em.clear();
        var turn = turnLogRepository.findBySessionIdAndTurnIndex(sessionId, 1).orElseThrow();
        assertThat(turn.getTranscript()).isEqualTo(PLAINTEXT);
        assertThat(turn.getGap()).isEqualByComparingTo("1.32");
        assertThat(turn.isGapTriggered()).isTrue();
        assertThat(turn.getTopProsody()).containsEntry("Tiredness", 0.71);

        List<String> tags = jdbc.queryForList(
                "select tag from turn_tag where turn_id = ?", String.class, turn.getId());
        assertThat(tags).containsExactly("회의");
    }

    /** <b>F5-02 수용 기준.</b> DB를 직접 조회해도 평문 발화가 보이지 않아야 한다. */
    @Test
    @DisplayName("DB를 직접 조회하면 발화가 암호문이다 — 엔티티로 읽으면 평문이다")
    void transcriptIsEncryptedAtRest() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", PLAINTEXT, null, null, null, false,
                List.of(), false);

        em.flush();
        String stored = jdbc.queryForObject(
                "select transcript_enc from turn_log where session_id = ?", String.class, sessionId);

        assertThat(stored).isNotEqualTo(PLAINTEXT);
        assertThat(stored).doesNotContain("회의");
        assertThat(stored).matches("[A-Za-z0-9+/=]+");

        em.clear();
        assertThat(turnLogRepository.findBySessionIdAndTurnIndex(sessionId, 1).orElseThrow()
                .getTranscript()).isEqualTo(PLAINTEXT);
    }

    /** <b>TC-06.</b> 분석 호출이 실패한 턴은 valence·gap이 전부 null, tags가 빈 배열로 온다. */
    @Test
    @DisplayName("분석 실패 턴도 정상 적재된다 (TC-06)")
    void analysisFailureTurnIsStored() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", "말은 했는데 분석이 안 됐어요",
                null, null, null, false, List.of(), false);

        em.clear();
        var turn = turnLogRepository.findBySessionIdAndTurnIndex(sessionId, 1).orElseThrow();
        assertThat(turn.getTextValence()).isNull();
        assertThat(turn.getVoiceValence()).isNull();
        assertThat(turn.getGap()).isNull();
        assertThat(turn.isGapTriggered()).isFalse();
    }

    // ── 중복 적재 처리 (3-1) ─────────────────────────────────────────

    /** 재시도 3회가 있어 같은 턴이 실제로 두 번 도착한다. 조용히 넘겨야 한다. */
    @Test
    @DisplayName("같은 턴을 두 번 보내면 행이 하나만 생기고 둘 다 202다")
    void retryIsIgnored() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", PLAINTEXT, null, null, null, false,
                List.of(), false);
        ingest(1, "2026-09-18T12:31:02.417Z", "user", PLAINTEXT, null, null, null, false,
                List.of(), false);

        em.flush();
        assertThat(countTurns()).isEqualTo(1);
    }

    /**
     * <b>판별이 없으면 이 방어가 유실 장치로 뒤집힌다.</b> 이어하기에서 인덱스가
     * 리셋되면 새 발화가 전부 "이미 적재됨"으로 202를 받고 오류 없이 사라진다.
     */
    @Test
    @DisplayName("같은 인덱스인데 발화 시각이 다르면 둘 다 남고 ops_error_log가 찍힌다")
    void collisionIsRenumberedAndLogged() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", "첫 번째 발화", null, null, null, false,
                List.of(), false);
        ingest(1, "2026-09-18T12:35:44.100Z", "user", "리셋 뒤에 들어온 다른 발화", null, null, null, false,
                List.of(), false);

        em.flush();
        assertThat(countTurns()).isEqualTo(2);
        assertThat(turnLogRepository.findBySessionIdAndTurnIndex(sessionId, 2)).isPresent();

        // sessionRef로 좁힌다 — ops_error_log는 REQUIRES_NEW로 쓰여 테스트 롤백에
        // 지워지지 않는다(그게 맞는 동작이다: 실패를 남기는 쪽이 대개 롤백되는 경로다).
        String sessionRef = SessionRef.of(sessionId.toString());
        List<Map<String, Object>> logs = jdbc.queryForList(
                "select code, message from ops_error_log"
                        + " where code = 'TURN_INDEX_COLLISION' and message like ?",
                "%sessionRef=" + sessionRef + "%");
        assertThat(logs).hasSize(1);

        String message = String.valueOf(logs.get(0).get("message"));
        assertThat(message).contains("sessionRef=");
        // 발화 내용도 sessionId 원본도 남지 않는다 (FR-092).
        assertThat(message).doesNotContain("발화").doesNotContain(sessionId.toString());
    }

    @Test
    @DisplayName("없는 세션의 턴은 404다 — AI서버는 4xx를 재시도하지 않는다")
    void unknownSessionIsRejected() throws Exception {
        mvc.perform(post("/internal/turns")
                        .header(SECRET_HEADER, SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(turnJson(UUID.randomUUID(), 1, "2026-09-18T12:31:02.417Z", "user",
                                PLAINTEXT, null, null, null, false, List.of(), false)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("SESSION_NOT_FOUND"));
    }

    @Test
    @DisplayName("공유 시크릿 없이는 턴을 넣을 수 없다")
    void ingestNeedsSharedSecret() throws Exception {
        mvc.perform(post("/internal/turns")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(turnJson(sessionId, 1, "2026-09-18T12:31:02.417Z", "user",
                                PLAINTEXT, null, null, null, false, List.of(), false)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INTERNAL_AUTH_FAILED"));
    }

    /**
     * 계약 §3-2에서 AI서버는 5xx를 <b>3회 재시도</b>한다. 깨진 본문에 500을 주면
     * 세 번 더 실패하고, 원인이 "본문이 깨졌다"가 아니라 "백엔드가 죽었다"로 보인다.
     */
    @Test
    @DisplayName("깨진 JSON은 500이 아니라 400이다 — 재시도해도 같은 결과다")
    void unreadableBodyIsClientError() throws Exception {
        mvc.perform(post("/internal/turns")
                        .header(SECRET_HEADER, SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"sessionId\": broken"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    // ── 위기 (F4) ───────────────────────────────────────────────────

    @Test
    @DisplayName("위기 감지는 crisis_event로만 가고 turn_id를 남기지 않는다")
    void crisisIsStoredWithoutTurnReference() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", "많이 힘들어요", null, null, null, false,
                List.of(), true);

        em.flush();
        Map<String, Object> event = jdbc.queryForMap("select * from crisis_event where session_id = ?", sessionId);
        assertThat(event).containsKeys("profile_id", "session_id", "detected_by");
        assertThat(event).doesNotContainKey("turn_id");
        assertThat(event.get("detected_by")).isEqualTo("rule");
    }

    // ── 대화 중 신호 (계약 §2-13) ────────────────────────────────────

    /** <b>TC-26.</b> FR-031 방어선이 여기서 이중이 된다 — 앱이 실수해도 그릴 데이터가 없다. */
    @Test
    @DisplayName("비데모 계정은 turns가 빈 배열이고 crisisDetected는 정상 값이다 (TC-26)")
    void liveHidesTurnsForNonDemo() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", PLAINTEXT, "0.70", "-0.62", "1.32", true,
                List.of(), true);
        em.flush();

        mvc.perform(get("/api/session/{id}/live", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turns").isArray())
                .andExpect(jsonPath("$.turns").isEmpty())
                .andExpect(jsonPath("$.lastTurnIndex").value(1))
                .andExpect(jsonPath("$.crisisDetected").value(true));
    }

    @Test
    @DisplayName("데모 모드는 turns를 채우고 sinceTurnIndex 이후만 준다")
    void liveShowsTurnsInDemoMode() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", "첫 턴", "0.10", "0.10", "0.00", false, List.of(), false);
        ingest(2, "2026-09-18T12:32:02.417Z", "user", "둘째 턴", "0.70", "-0.62", "1.32", true, List.of(), false);
        em.flush();
        jdbc.update("update profile set demo_mode = true where id = ?", profileId);
        em.clear();

        mvc.perform(get("/api/session/{id}/live", sessionId)
                        .param("sinceTurnIndex", "1")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.turns.length()").value(1))
                .andExpect(jsonPath("$.turns[0].turnIndex").value(2))
                .andExpect(jsonPath("$.turns[0].gap").value(1.32))
                .andExpect(jsonPath("$.turns[0].gapTriggered").value(true));
    }

    @Test
    @DisplayName("남의 세션 신호는 볼 수 없다")
    void liveForbidsOtherProfile() throws Exception {
        String otherJwt = jwtProvider.issue(profileRepository.save(Profile.create()).getId()).token();

        mvc.perform(get("/api/session/{id}/live", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherJwt))
                .andExpect(status().isForbidden());
    }

    // ── baseline 갱신 (F3-05) ────────────────────────────────────────

    /** 갭이 NULL인 턴은 집계에서 빠진다. 그 턴이 평균을 끌어내리면 임계값이 틀어진다. */
    @Test
    @DisplayName("세션 종료가 avg_gap을 다시 계산한다 — 갭 없는 턴은 빼고")
    void baselineIsRecalculatedOnEnd() throws Exception {
        ingest(1, "2026-09-18T12:31:02.417Z", "user", "하나", "0.5", "0.1", "0.40", false, List.of(), false);
        ingest(2, "2026-09-18T12:32:02.417Z", "user", "둘", "0.5", "-0.1", "0.60", false, List.of(), false);
        ingest(3, "2026-09-18T12:33:02.417Z", "assistant", "분석 없는 턴", null, null, null, false, List.of(), false);
        em.flush();

        mvc.perform(post("/api/session/{id}/end", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"endReason\":\"user_end\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turnCount").value(3))
                .andExpect(jsonPath("$.gapAvg").value(0.5))
                // AI서버가 없으므로 요약은 null이다 — 대화 기록 자체는 남는다.
                .andExpect(jsonPath("$.summary").doesNotExist());

        // flush 없이 clear하면 대기 중인 UPDATE가 그대로 버려져 DB에는 아무것도 안 남는다.
        em.flush();
        em.clear();
        var baseline = baselineRepository.findById(profileId).orElseThrow();
        assertThat(baseline.getAvgGap()).isEqualByComparingTo("0.50");
        assertThat(baseline.getSessionCount()).isEqualTo(1);
    }

    // ── 도구 ────────────────────────────────────────────────────────

    private void ingest(int turnIndex, String occurredAt, String role, String transcript,
                        String textValence, String voiceValence, String gap, boolean gapTriggered,
                        List<String> tags, boolean crisis) throws Exception {
        mvc.perform(post("/internal/turns")
                        .header(SECRET_HEADER, SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(turnJson(sessionId, turnIndex, occurredAt, role, transcript,
                                textValence, voiceValence, gap, gapTriggered, tags, crisis)))
                .andExpect(status().isAccepted());
    }

    private String turnJson(UUID session, int turnIndex, String occurredAt, String role, String transcript,
                            String textValence, String voiceValence, String gap, boolean gapTriggered,
                            List<String> tags, boolean crisis) {
        String tagJson = tags.stream().map(t -> "\"" + t + "\"").reduce((a, b) -> a + "," + b).orElse("");
        return """
                {
                  "sessionId": "%s",
                  "turnIndex": %d,
                  "role": "%s",
                  "occurredAt": "%s",
                  "transcript": "%s",
                  "textValence": %s,
                  "voiceValence": %s,
                  "gap": %s,
                  "gapTriggered": %s,
                  "thresholdMode": "fixed",
                  "tags": [%s],
                  "topProsody": { "Tiredness": 0.71, "Sadness": 0.42 },
                  "crisis": { "detected": %s, "by": %s }
                }
                """.formatted(session, turnIndex, role, occurredAt, transcript,
                nullOr(textValence), nullOr(voiceValence), nullOr(gap), gapTriggered, tagJson,
                crisis, crisis ? "\"rule\"" : "null");
    }

    private String nullOr(String value) {
        return value == null ? "null" : value;
    }

    private int countTurns() {
        Integer count = jdbc.queryForObject(
                "select count(*) from turn_log where session_id = ?", Integer.class, sessionId);
        return count == null ? 0 : count;
    }
}
