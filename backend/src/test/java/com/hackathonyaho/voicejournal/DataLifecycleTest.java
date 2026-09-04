package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import com.hackathonyaho.voicejournal.common.crypto.TranscriptConverter;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Phase 6 — 삭제 · 연쇄 무효화 · 탈퇴. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class DataLifecycleTest {

    @Autowired MockMvc mvc;
    @Autowired JwtProvider jwtProvider;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired VoiceSessionRepository sessionRepository;
    @Autowired ObservationRepository observationRepository;
    @Autowired TranscriptConverter converter;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager em;

    @org.springframework.test.context.bean.override.mockito.MockitoSpyBean
    com.hackathonyaho.voicejournal.session.repository.TurnStats turnStats;

    private UUID profileId;
    private UUID sessionId;
    private String jwt;

    @BeforeEach
    void setUp() {
        profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));
        sessionId = newSession();
        jwt = jwtProvider.issue(profileId).token();
        // 삭제는 생 SQL이라 JPA가 아직 쓰지 않은 행을 보지 못한다. 운영에서는 이전
        // 요청에서 이미 커밋된 행이지만, 테스트는 한 트랜잭션 안이라 여기서 맞춰준다.
        // (롤백 테스트만 트랜잭션 밖이라 flush 대상이 없다 — 이미 커밋돼 있다.)
        flushIfInTransaction();
    }

    // ── 세션 삭제 (F10-01) ───────────────────────────────────────────

    @Test
    @DisplayName("세션을 지우면 턴·태그·위기가 함께 사라지고 건수가 응답에 담긴다")
    void deleteRemovesEverythingUnderSession() throws Exception {
        turn(sessionId, 1, "0.90", "회의");
        turn(sessionId, 2, "0.90", "회의");
        jdbc.update("insert into crisis_event (profile_id, session_id, detected_by) values (?, ?, 'rule')",
                profileId, sessionId);
        em.clear();

        mvc.perform(delete("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deletedSessionId").value(sessionId.toString()))
                .andExpect(jsonPath("$.deletedTurnCount").value(2));

        assertThat(count("turn_log", "session_id", sessionId)).isZero();
        assertThat(count("crisis_event", "session_id", sessionId)).isZero();
        assertThat(count("voice_session", "id", sessionId)).isZero();
        assertThat(jdbc.queryForObject("select count(*) from turn_tag", Integer.class)).isZero();
    }

    @Test
    @DisplayName("세션을 지우면 그 대화가 기록 목록과 트렌드에서도 사라진다")
    void deletedSessionDisappearsFromQueries() throws Exception {
        turn(sessionId, 1, "0.90", "회의");
        endSession(sessionId);

        mvc.perform(get("/api/sessions").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(1));

        mvc.perform(delete("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk());

        mvc.perform(get("/api/sessions").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.total").value(0));
        mvc.perform(get("/api/trend").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.points").isEmpty());
    }

    @Test
    @DisplayName("남의 세션은 지울 수 없다")
    void deleteForbidsOtherProfile() throws Exception {
        String otherJwt = jwtProvider.issue(profileRepository.save(Profile.create()).getId()).token();

        mvc.perform(delete("/api/sessions/{id}", sessionId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + otherJwt))
                .andExpect(status().isForbidden());
        assertThat(count("voice_session", "id", sessionId)).isEqualTo(1);
    }

    // ── 연쇄 무효화 (F10-02) ─────────────────────────────────────────

    /**
     * <b>TC-19.</b> 근거 대화가 삭제됐는데 관찰만 남으면 그 관찰은 그 순간
     * "근거 없는 문장"이 된다.
     */
    @Test
    @DisplayName("남은 근거가 3회 미만이 되면 관찰이 삭제된다 (TC-19)")
    void observationRemovedWhenEvidenceDropsBelowThree() throws Exception {
        UUID other = newSession();
        UUID keep = turn(other, 1, "1.50", "회의");
        UUID doomed1 = turn(sessionId, 1, "1.50", "회의");
        UUID doomed2 = turn(sessionId, 2, "1.50", "회의");
        UUID observationId = observation("회의", 3, "1.50", "0.80", "1.88");
        link(observationId, keep);
        link(observationId, doomed1);
        link(observationId, doomed2);

        mvc.perform(delete("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.removedObservationIds[0]").value(observationId.toString()))
                .andExpect(jsonPath("$.recalculatedObservationIds").isEmpty());

        em.clear();
        assertThat(observationRepository.findById(observationId)).isEmpty();
        assertThat(count("observation_evidence", "observation_id", observationId)).isZero();
    }

    /** 생성될 수 없었을 관찰이 삭제 후에 살아남으면 안 된다 — 3회 기준은 F7-03과 같다. */
    @Test
    @DisplayName("근거가 3회 이상 남으면 숫자가 재계산되고 관찰은 유지된다 (TC-19)")
    void observationRecalculatedWhenEvidenceRemains() throws Exception {
        UUID other = newSession();
        UUID observationId = observation("회의", 4, "1.50", "0.80", "1.88");
        for (int i = 1; i <= 3; i++) {
            link(observationId, turn(other, i, "1.20", "회의"));
        }
        link(observationId, turn(sessionId, 1, "1.50", "회의"));
        jdbc.update("update user_baseline set avg_gap = 0.60 where profile_id = ?", profileId);
        em.clear();

        mvc.perform(delete("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recalculatedObservationIds[0]").value(observationId.toString()))
                .andExpect(jsonPath("$.removedObservationIds").isEmpty());

        em.clear();
        Observation observation = observationRepository.findById(observationId).orElseThrow();
        assertThat(observation.getOccurrences()).isEqualTo(3);
        assertThat(observation.getTagAvgGap()).isEqualByComparingTo("1.20");
        // baseline이 먼저 재계산되므로 evidence.userAvgGap이 트렌드와 같은 값이다.
        assertThat(observation.getUserAvgGap()).isEqualByComparingTo("1.20");
        assertThat(observation.getRatio()).isEqualByComparingTo("1.00");
    }

    /** 화면 두 곳이 다른 숫자를 보이면 그게 곧 §1.4 "evidence 불일치"다. */
    @Test
    @DisplayName("삭제 후에도 관찰 evidence.userAvgGap과 trend userAvgGap이 같다")
    void userAvgGapStaysAlignedAfterDelete() throws Exception {
        UUID other = newSession();
        UUID observationId = observation("회의", 4, "1.50", "0.80", "1.88");
        for (int i = 1; i <= 3; i++) {
            link(observationId, turn(other, i, "1.20", "회의"));
        }
        link(observationId, turn(sessionId, 1, "0.20", "회의"));
        endSession(other);

        mvc.perform(delete("/api/sessions/{id}", sessionId).header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isOk());
        em.clear();

        BigDecimal fromObservation = observationRepository.findById(observationId).orElseThrow().getUserAvgGap();
        mvc.perform(get("/api/trend").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(jsonPath("$.userAvgGap").value(fromObservation.doubleValue()));
    }

    /**
     * "절반만 지워진" 상태를 만들지 않는다. 이 테스트가 없으면 <b>트랜잭션 경계가
     * 잘못돼도 정상 경로에서는 티가 안 난다</b> — 삭제는 어차피 되니까.
     */
    /**
     * "절반만 지워진" 상태를 만들지 않는다.
     *
     * <p><b>이 테스트만 트랜잭션 밖에서 돈다.</b> 클래스 기본값처럼 테스트와 서비스가
     * 한 트랜잭션을 공유하면 서비스의 롤백이 테스트에는 보이지 않는다 — 커밋 경계가
     * 테스트 종료 시점이라, 정작 <b>확인하려는 경계가 확인되지 않는다.</b>
     */
    @Test
    @org.springframework.transaction.annotation.Transactional(
            propagation = org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
    @DisplayName("삭제 도중 예외가 나면 아무것도 지워지지 않는다")
    void deleteRollsBackOnFailure() throws Exception {
        UUID turnId = UUID.randomUUID();
        jdbc.update("insert into turn_log (id, session_id, turn_index, role, occurred_at, transcript_enc, gap)"
                        + " values (?, ?, 1, 'user', ?, ?, 0.90)",
                turnId, sessionId, Timestamp.from(Instant.now()),
                converter.convertToDatabaseColumn("그날의 발화"));

        // baseline 재계산(⑧)에서 터뜨린다 — 턴·세션 삭제가 이미 지나간 뒤다.
        org.mockito.BDDMockito.willThrow(new IllegalStateException("boom"))
                .given(turnStats).baselineFor(org.mockito.ArgumentMatchers.any());
        try {
            mvc.perform(delete("/api/sessions/{id}", sessionId)
                            .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                    .andExpect(status().isInternalServerError());

            assertThat(count("voice_session", "id", sessionId)).isEqualTo(1);
            assertThat(count("turn_log", "session_id", sessionId)).isEqualTo(1);
        } finally {
            // 트랜잭션 밖이라 테스트가 스스로 치운다.
            jdbc.update("delete from turn_log where session_id = ?", sessionId);
            jdbc.update("delete from voice_session where profile_id = ?", profileId);
            jdbc.update("delete from user_baseline where profile_id = ?", profileId);
            jdbc.update("delete from profile where id = ?", profileId);
        }
    }

    // ── 탈퇴 (F10-03) ───────────────────────────────────────────────

    /** <b>TC-13.</b> 같은 카카오 계정으로 재가입하면 신규 사용자로 시작해야 한다. */
    @Test
    @DisplayName("탈퇴하면 10개 테이블에서 그 사용자가 0건이 된다 (TC-13)")
    void withdrawDeletesEverything() throws Exception {
        UUID turnId = turn(sessionId, 1, "0.90", "회의");
        UUID observationId = observation("회의", 3, "1.50", "0.80", "1.88");
        link(observationId, turnId);
        jdbc.update("insert into crisis_event (profile_id, session_id, detected_by) values (?, ?, 'llm')",
                profileId, sessionId);
        UUID accountId = jdbc.queryForObject(
                "insert into account (kakao_id) values ('9999999') returning id", UUID.class);
        jdbc.update("insert into account_profile (account_id, profile_id) values (?, ?)", accountId, profileId);
        em.clear();

        mvc.perform(delete("/api/account").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNoContent());

        assertThat(count("observation_evidence", "observation_id", observationId)).isZero();
        assertThat(count("observation", "profile_id", profileId)).isZero();
        assertThat(count("turn_log", "session_id", sessionId)).isZero();
        assertThat(count("crisis_event", "profile_id", profileId)).isZero();
        assertThat(count("voice_session", "profile_id", profileId)).isZero();
        assertThat(count("user_baseline", "profile_id", profileId)).isZero();
        assertThat(count("account_profile", "profile_id", profileId)).isZero();
        assertThat(count("account", "id", accountId)).isZero();
        assertThat(count("profile", "id", profileId)).isZero();
    }

    /** 사용자 데이터를 담지 않고 장애 분석에 필요하다 (spec §6-1). */
    @Test
    @DisplayName("탈퇴해도 ops_error_log는 지우지 않는다")
    void withdrawKeepsOpsErrorLog() throws Exception {
        jdbc.update("insert into ops_error_log (service, code, message) values ('backend', 'TEST_KEEP', ?)",
                "sessionRef=deadbeef");
        int before = jdbc.queryForObject(
                "select count(*) from ops_error_log where code = 'TEST_KEEP'", Integer.class);

        mvc.perform(delete("/api/account").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNoContent());

        assertThat(jdbc.queryForObject(
                "select count(*) from ops_error_log where code = 'TEST_KEEP'", Integer.class))
                .isEqualTo(before);
    }

    /** 본문이 없어도 탈퇴는 성립한다 — unlink는 선택이다(계약 §2-3 v1.6). */
    @Test
    @DisplayName("탈퇴 본문이 없어도 204이고 데이터는 지워진다")
    void withdrawWithoutBodyStillDeletes() throws Exception {
        mvc.perform(delete("/api/account").header(HttpHeaders.AUTHORIZATION, "Bearer " + jwt))
                .andExpect(status().isNoContent());
        assertThat(count("profile", "id", profileId)).isZero();
    }

    // ── 도구 ────────────────────────────────────────────────────────

    private UUID newSession() {
        return sessionRepository.save(
                VoiceSession.start(profileId, "fixed", new BigDecimal("0.85"))).getId();
    }

    private UUID observation(String tag, int occurrences, String tagAvgGap, String userAvgGap, String ratio) {
        return observationRepository.saveAndFlush(Observation.of(profileId,
                tag + " 얘기를 하실 때만 목소리가 유독 무거워지시네요.", tag, occurrences,
                new BigDecimal(tagAvgGap), new BigDecimal(userAvgGap), new BigDecimal(ratio))).getId();
    }

    private UUID turn(UUID session, int turnIndex, String gap, String tag) {
        flushIfInTransaction();
        UUID turnId = UUID.randomUUID();
        jdbc.update("insert into turn_log (id, session_id, turn_index, role, occurred_at, transcript_enc, gap)"
                        + " values (?, ?, ?, 'user', ?, ?, ?)",
                turnId, session, turnIndex, Timestamp.from(Instant.now().plusSeconds(turnIndex)),
                converter.convertToDatabaseColumn("그날의 발화"), new BigDecimal(gap));
        jdbc.update("insert into turn_tag (turn_id, tag) values (?, ?)", turnId, tag);
        em.clear();
        return turnId;
    }

    private void link(UUID observationId, UUID turnId) {
        flushIfInTransaction();
        jdbc.update("insert into observation_evidence (observation_id, turn_id) values (?, ?)",
                observationId, turnId);
        em.clear();
    }

    private void endSession(UUID session) {
        flushIfInTransaction();
        jdbc.update("update voice_session set ended_at = ?, duration_sec = 120, end_reason = 'user_end'"
                + " where id = ?", Timestamp.from(Instant.now()), session);
        em.clear();
    }

    private void flushIfInTransaction() {
        if (org.springframework.transaction.support.TransactionSynchronizationManager
                .isActualTransactionActive()) {
            em.flush();
        }
    }

    private int count(String table, String column, UUID value) {
        flushIfInTransaction();
        Integer count = jdbc.queryForObject(
                "select count(*) from " + table + " where " + column + " = ?", Integer.class, value);
        return count == null ? 0 : count;
    }
}
