package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.observation.entity.Observation;
import com.hackathonyaho.voicejournal.observation.repository.ObservationRepository;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
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
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Phase 5 — 조회 API (관찰 · 트렌드 · 기록). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DashboardApiTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired VoiceSessionRepository sessionRepository;
    @Autowired ObservationRepository observationRepository;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager em;
    @Autowired com.hackathonyaho.voicejournal.common.crypto.TranscriptConverter converter;

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

    // ── 관찰 목록 (F7-06) ────────────────────────────────────────────

    /** 관찰 문장만 있고 근거가 없는 상태를 계약 수준에서 만들지 않는다 (FR-053). */
    @Test
    @DisplayName("목록에도 evidence 5키가 함께 내려간다")
    void listCarriesEvidence() throws Exception {
        observation("회의", 7, "1.31", "0.72", "1.82");

        mvc.perform(get("/api/observations").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.observations[0].evidence.tag").value("회의"))
                .andExpect(jsonPath("$.observations[0].evidence.occurrences").value(7))
                .andExpect(jsonPath("$.observations[0].evidence.tagAvgGap").value(1.31))
                .andExpect(jsonPath("$.observations[0].evidence.userAvgGap").value(0.72))
                .andExpect(jsonPath("$.observations[0].evidence.ratio").value(1.82))
                .andExpect(jsonPath("$.observations[0].feedback").doesNotExist());
    }

    /** "아직 없어요" 안내는 앱이 한다 — 서버가 억지 문구를 만들지 않는다 (계약 §1-3). */
    @Test
    @DisplayName("관찰이 없으면 빈 배열이다 — 오류가 아니다")
    void emptyListIsNotAnError() throws Exception {
        mvc.perform(get("/api/observations").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(0))
                .andExpect(jsonPath("$.observations").isEmpty());
    }

    @Test
    @DisplayName("무효화된 관찰은 목록에도 상세에도 나오지 않는다")
    void invalidatedIsHidden() throws Exception {
        UUID observationId = observation("회의", 3, "1.30", "0.80", "1.63");
        em.flush();
        jdbc.update("update observation set status = 'invalidated' where id = ?", observationId);
        em.clear();

        mvc.perform(get("/api/observations").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(0));
        mvc.perform(get("/api/observations/{id}/evidence", observationId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("OBSERVATION_NOT_FOUND"));
    }

    // ── 관찰 근거 (F7-07) ────────────────────────────────────────────

    /** <b>TC-17.</b> turns 길이 ≠ occurrences면 계약 위반이고 §1.4 지표 실패다. */
    @Test
    @DisplayName("근거 대화 건수가 evidence.occurrences와 같고 발화가 평문으로 나온다")
    void evidenceTurnsMatchOccurrences() throws Exception {
        UUID observationId = observation("회의", 2, "1.30", "0.80", "1.63");
        UUID first = turn(1, "1.20", "회의", "오늘 회의가 세 개나 있었는데 다 괜찮았어요");
        UUID second = turn(2, "1.40", "회의", "회의가 길어졌어요");
        link(observationId, first);
        link(observationId, second);

        mvc.perform(get("/api/observations/{id}/evidence", observationId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.evidence.occurrences").value(2))
                .andExpect(jsonPath("$.turns.length()").value(2))
                .andExpect(jsonPath("$.turns[0].transcript").value("오늘 회의가 세 개나 있었는데 다 괜찮았어요"))
                .andExpect(jsonPath("$.turns[0].gap").value(1.20));
    }

    @Test
    @DisplayName("남의 관찰은 볼 수 없다")
    void otherProfileObservationIsHidden() throws Exception {
        UUID observationId = observation("회의", 3, "1.30", "0.80", "1.63");
        String otherJwt = jwtProvider.issue(profileRepository.save(Profile.create()).getId()).token();

        mvc.perform(get("/api/observations/{id}/evidence", observationId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherJwt))
                .andExpect(status().isNotFound());
    }

    // ── 피드백 (F7-08, P1) ───────────────────────────────────────────

    /** <b>TC-23.</b> 부정해도 우리가 계산한 숫자가 틀린 것은 아니다 — evidence는 유효하다. */
    @Test
    @DisplayName("아니에요를 골라도 관찰과 evidence가 그대로 남는다 (TC-23)")
    void disagreeKeepsObservation() throws Exception {
        UUID observationId = observation("회의", 7, "1.31", "0.72", "1.82");

        mvc.perform(post("/api/observations/{id}/feedback", observationId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"feedback\":\"disagree\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.feedback").value("disagree"));

        mvc.perform(get("/api/observations").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.observations[0].feedback").value("disagree"))
                .andExpect(jsonPath("$.observations[0].evidence.occurrences").value(7));
    }

    @Test
    @DisplayName("agree·disagree 외의 값은 400이다")
    void feedbackValueIsRestricted() throws Exception {
        UUID observationId = observation("회의", 3, "1.30", "0.80", "1.63");

        mvc.perform(post("/api/observations/{id}/feedback", observationId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"feedback\":\"maybe\"}"))
                .andExpect(status().isBadRequest());
    }

    // ── 트렌드 (F9) ─────────────────────────────────────────────────

    /** <b>TC-18.</b> 데이터 없는 날을 0으로 채우면 없는 감정을 그리는 것이 된다. */
    @Test
    @DisplayName("기록 없는 날은 points에서 아예 빠진다 (TC-18)")
    void missingDaysAreOmitted() throws Exception {
        turnAt(1, "0.40", daysAgoKst(3));
        turnAt(2, "0.60", daysAgoKst(1));

        mvc.perform(get("/api/trend").param("range", "7d")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").value("Asia/Seoul"))
                .andExpect(jsonPath("$.range").value("7d"))
                .andExpect(jsonPath("$.points.length()").value(2))
                .andExpect(jsonPath("$.points[0].date").value(daysAgoKst(3).toString()))
                .andExpect(jsonPath("$.points[1].date").value(daysAgoKst(1).toString()));
    }

    /** 세 곳(baseline·관찰 evidence·트렌드)이 같은 값을 보여야 §1.4가 성립한다. */
    @Test
    @DisplayName("trend의 userAvgGap이 관찰 evidence.userAvgGap과 같은 값이다")
    void userAvgGapIsTheSameEverywhere() throws Exception {
        em.flush();
        jdbc.update("update user_baseline set avg_gap = 0.72 where profile_id = ?", profileId);
        em.clear();
        observation("회의", 7, "1.31", "0.72", "1.82");

        mvc.perform(get("/api/trend").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.userAvgGap").value(0.72));
    }

    /**
     * 임계값은 20쌍 측정 후 반드시 한 번 바뀐다(PRD §14-5). 현재값으로 소급 판정하면
     * 그 순간 <b>과거 음영이 통째로 달라진다.</b>
     */
    @Test
    @DisplayName("highlights는 그날 세션의 임계값 스냅샷으로 판정한다")
    void highlightsUseSessionSnapshot() throws Exception {
        // 이 세션의 스냅샷은 0.85다. 갭 0.90은 그것을 넘는다.
        turnAt(1, "0.90", daysAgoKst(2));
        turnAt(2, "0.90", daysAgoKst(1));

        mvc.perform(get("/api/trend").param("range", "7d")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.highlights.length()").value(1))
                .andExpect(jsonPath("$.highlights[0].from").value(daysAgoKst(2).toString()))
                .andExpect(jsonPath("$.highlights[0].to").value(daysAgoKst(1).toString()))
                .andExpect(jsonPath("$.highlights[0].reason").value("gap_exceeded"));

        // 스냅샷을 높이면 같은 데이터가 더는 구간이 아니다 — 현재값이 아니라 그날 값을 본다.
        em.flush();
        jdbc.update("update voice_session set gap_threshold = 1.50 where id = ?", sessionId);
        em.clear();

        mvc.perform(get("/api/trend").param("range", "7d")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.highlights").isEmpty());
    }

    /** 넘은 것만 보이면 비교 대상이 없어 "왜 이게 발견인가"가 설명되지 않는다. */
    @Test
    @DisplayName("tagGaps에 3회 이상이지만 1.5배 미만인 태그도 나온다 — 3회 미만은 빠진다")
    void tagGapsIncludeBelowThreshold() throws Exception {
        turn(1, "0.90", "야근", "야근했어요");
        turn(2, "0.90", "야근", "또 야근이에요");
        turn(3, "0.90", "야근", "야근 끝났어요");
        turn(4, "1.90", "가족", "가족 이야기");

        mvc.perform(get("/api/trend").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.tagGaps.length()").value(1))
                .andExpect(jsonPath("$.tagGaps[0].tag").value("야근"))
                .andExpect(jsonPath("$.tagGaps[0].occurrences").value(3));
    }

    // ── 대화 기록 (F9-04·05) ─────────────────────────────────────────

    @Test
    @DisplayName("기록 목록은 끝난 세션만, 태그는 상위 3개까지")
    void sessionListShowsEndedOnly() throws Exception {
        turn(1, "1.20", "회의", "회의 얘기");
        turn(2, "0.80", "회의", "회의 또");
        turn(3, "0.40", "야근", "야근 얘기");

        // 아직 안 끝난 세션은 기록이 아니다.
        mvc.perform(get("/api/sessions").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(0));

        endSession();
        mvc.perform(get("/api/sessions").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.sessions[0].turnCount").value(3))
                .andExpect(jsonPath("$.sessions[0].gapAvg").value(0.80))
                .andExpect(jsonPath("$.sessions[0].tags[0]").value("회의"));
    }

    @Test
    @DisplayName("상세는 상단 정보와 턴을 함께 주고 assistant 턴은 전부 null이다")
    void sessionDetailCarriesHeaderAndTurns() throws Exception {
        turn(1, "1.20", "회의", "오늘 회의가 세 개나 있었는데 다 괜찮았어요");
        assistantTurn(2, "괜찮다고 하시는데 목소리는 좀 다르네요.");
        endSession();

        mvc.perform(get("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.endReason").value("user_end"))
                .andExpect(jsonPath("$.thresholdMode").value("fixed"))
                .andExpect(jsonPath("$.turns.length()").value(2))
                .andExpect(jsonPath("$.turns[0].transcript").value("오늘 회의가 세 개나 있었는데 다 괜찮았어요"))
                .andExpect(jsonPath("$.turns[0].gap").value(1.20))
                .andExpect(jsonPath("$.turns[0].tags[0]").value("회의"))
                .andExpect(jsonPath("$.turns[1].role").value("assistant"))
                .andExpect(jsonPath("$.turns[1].gap").doesNotExist())
                .andExpect(jsonPath("$.turns[1].tags").isEmpty());
    }

    @Test
    @DisplayName("남의 대화 상세는 403이다")
    void sessionDetailForbidsOtherProfile() throws Exception {
        String otherJwt = jwtProvider.issue(profileRepository.save(Profile.create()).getId()).token();

        mvc.perform(get("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + otherJwt))
                .andExpect(status().isForbidden());
    }

    // ── 도구 ────────────────────────────────────────────────────────

    private UUID observation(String tag, int occurrences, String tagAvgGap, String userAvgGap, String ratio) {
        return observationRepository.saveAndFlush(Observation.of(profileId,
                tag + " 얘기를 하실 때만 목소리가 유독 무거워지시네요.", tag, occurrences,
                new BigDecimal(tagAvgGap), new BigDecimal(userAvgGap), new BigDecimal(ratio))).getId();
    }

    private UUID turn(int turnIndex, String gap, String tag, String transcript) {
        UUID turnId = insertTurn(turnIndex, gap, transcript, "user", Instant.now().plusSeconds(turnIndex));
        jdbc.update("insert into turn_tag (turn_id, tag) values (?, ?)", turnId, tag);
        em.clear();
        return turnId;
    }

    private void assistantTurn(int turnIndex, String transcript) {
        insertTurn(turnIndex, null, transcript, "assistant", Instant.now().plusSeconds(turnIndex));
        em.clear();
    }

    private void turnAt(int turnIndex, String gap, LocalDate kstDate) {
        insertTurn(turnIndex, gap, "그날의 발화", "user", kstDate.atTime(12, 0).atZone(KST).toInstant());
        em.clear();
    }

    /** 본문은 변환기가 암호화한다 — 여기서는 평문으로 넣고 읽을 때 평문으로 나오는지 본다. */
    private UUID insertTurn(int turnIndex, String gap, String transcript, String role, Instant occurredAt) {
        em.flush();
        UUID turnId = UUID.randomUUID();
        jdbc.update("insert into turn_log (id, session_id, turn_index, role, occurred_at, transcript_enc, gap)"
                        + " values (?, ?, ?, ?, ?, ?, ?)",
                turnId, sessionId, turnIndex, role, Timestamp.from(occurredAt),
                encrypt(transcript), gap == null ? null : new BigDecimal(gap));
        return turnId;
    }

    private String encrypt(String plaintext) {
        return converter.convertToDatabaseColumn(plaintext);
    }

    private void endSession() {
        em.flush();
        jdbc.update("update voice_session set ended_at = ?, duration_sec = 180, end_reason = 'user_end' where id = ?",
                Timestamp.from(Instant.now()), sessionId);
        em.clear();
    }

    private void link(UUID observationId, UUID turnId) {
        em.flush();
        jdbc.update("insert into observation_evidence (observation_id, turn_id) values (?, ?)",
                observationId, turnId);
        em.clear();
    }

    private LocalDate daysAgoKst(int days) {
        return LocalDate.now(KST).minus(days, ChronoUnit.DAYS);
    }
}
