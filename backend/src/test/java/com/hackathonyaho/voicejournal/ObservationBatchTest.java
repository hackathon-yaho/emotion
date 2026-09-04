package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.observation.entity.Observation;
import com.hackathonyaho.voicejournal.observation.repository.ObservationRepository;
import com.hackathonyaho.voicejournal.observation.service.ObservationBatchService;
import com.hackathonyaho.voicejournal.observation.service.ObservationSentenceClient;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.given;

/**
 * Phase 4 — 패턴 배치.
 *
 * <p><b>AI서버만 대역을 쓴다.</b> 문장화는 LLM이 하는 일이고, 여기서 확인할 것은
 * <b>판정이 코드에서 이뤄지는지</b>다(FR-051·052·054).
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ObservationBatchTest {

    @Autowired ObservationBatchService batchService;
    @Autowired ProfileRepository profileRepository;
    @Autowired UserBaselineRepository baselineRepository;
    @Autowired VoiceSessionRepository sessionRepository;
    @Autowired ObservationRepository observationRepository;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager em;

    @MockitoBean ObservationSentenceClient sentenceClient;

    private UUID profileId;
    private UUID sessionId;

    @BeforeEach
    void setUp() {
        given(sentenceClient.sentenceFor(anyString(), anyInt(), any(), any(), any()))
                .willReturn("회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.");

        profileId = profileRepository.save(Profile.create()).getId();
        baselineRepository.save(new UserBaseline(profileId));
        sessionId = sessionRepository.save(
                VoiceSession.start(profileId, "fixed", new BigDecimal("0.85"))).getId();
    }

    // ── 판정 (F7-03) ────────────────────────────────────────────────

    @Test
    @DisplayName("3회 이상 · 평균의 1.5배 이상이면 관찰이 생기고 근거 턴이 연결된다")
    void createsObservationWhenBothConditionsPass() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        setUserAvgGap("0.80");
        endSession();

        assertThat(batchService.runPending()).isEqualTo(1);
        em.flush();

        Observation observation = observationRepository.findAll().stream()
                .filter(o -> o.getProfileId().equals(profileId)).findFirst().orElseThrow();
        assertThat(observation.getTag()).isEqualTo("회의");
        assertThat(observation.getOccurrences()).isEqualTo(3);
        assertThat(observation.getTagAvgGap()).isEqualByComparingTo("1.50");
        assertThat(observation.getUserAvgGap()).isEqualByComparingTo("0.80");
        assertThat(observation.getRatio()).isEqualByComparingTo("1.88");
        assertThat(observation.getStatus()).isEqualTo(Observation.ACTIVE);

        // TC-17 — evidence 숫자와 실제 근거 건수가 같아야 한다.
        Integer linked = jdbc.queryForObject(
                "select count(*) from observation_evidence where observation_id = ?",
                Integer.class, observation.getId());
        assertThat(linked).isEqualTo(observation.getOccurrences());
    }

    /** <b>TC-16.</b> 데이터가 부족한 사용자에게 관찰이 안 생기는 것은 버그가 아니라 사양이다. */
    @Test
    @DisplayName("태그가 2회만 등장하면 갭이 아무리 커도 관찰이 없다 (TC-16)")
    void silentWhenOccurrencesBelowThree() {
        turn(1, "1.90", "회의");
        turn(2, "1.90", "회의");
        setUserAvgGap("0.50");
        endSession();

        assertThat(batchService.runPending()).isZero();
        assertThat(observationsOfProfile()).isEmpty();
    }

    @Test
    @DisplayName("3회를 넘겨도 평균의 1.5배에 못 미치면 관찰이 없다")
    void silentWhenRatioBelowThreshold() {
        turn(1, "0.90", "회의");
        turn(2, "0.90", "회의");
        turn(3, "0.90", "회의");
        setUserAvgGap("0.80"); // 1.5배 = 1.20 > 0.90
        endSession();

        assertThat(batchService.runPending()).isZero();
        assertThat(observationsOfProfile()).isEmpty();
    }

    /** 분석이 한 번도 성공하지 않은 사용자다. 비율을 낼 분모가 없다. */
    @Test
    @DisplayName("avg_gap이 NULL이면 판정 자체를 하지 않는다")
    void silentWhenBaselineMissing() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        endSession();

        assertThat(batchService.runPending()).isZero();
    }

    /** 갭이 NULL인 턴을 0으로 세면 평균이 내려가 조건 판정이 틀어진다. */
    @Test
    @DisplayName("갭이 NULL인 턴은 등장 횟수에서도 빠진다")
    void nullGapTurnsAreExcluded() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, null, "회의"); // 분석 실패 턴 — 세지 않는다
        setUserAvgGap("0.80");
        endSession();

        assertThat(batchService.runPending()).isZero();
    }

    // ── AI 실패 (F7-04) ─────────────────────────────────────────────

    /** 표현이 어색한 것보다 <b>근거 없는 문장이 나가는 쪽</b>이 위험하다. */
    @Test
    @DisplayName("문장화가 실패하면 관찰을 만들지 않는다 — 템플릿으로 대체하지 않는다")
    void noObservationWhenSentenceFails() {
        given(sentenceClient.sentenceFor(anyString(), anyInt(), any(), any(), any())).willReturn(null);
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        setUserAvgGap("0.80");
        endSession();

        assertThat(batchService.runPending()).isZero();
        assertThat(observationsOfProfile()).isEmpty();
    }

    // ── 배치 트리거 (F7-01) ──────────────────────────────────────────

    @Test
    @DisplayName("처리한 세션만 pattern_processed_at이 찍히고 다음 주기에 다시 돌지 않는다")
    void processedSessionIsNotPickedUpAgain() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        setUserAvgGap("0.80");
        endSession();

        assertThat(batchService.runPending()).isEqualTo(1);
        em.flush();
        assertThat(sessionRepository.findById(sessionId).orElseThrow().getPatternProcessedAt()).isNotNull();

        // 두 번째 주기 — 이미 처리됐으므로 대상이 없다.
        assertThat(batchService.runPending()).isZero();
    }

    /** 끝나지 않은 세션을 집계하면 대화 도중에 관찰이 튀어나온다. */
    @Test
    @DisplayName("종료되지 않은 세션은 배치 대상이 아니다")
    void openSessionIsNotBatched() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        setUserAvgGap("0.80");
        em.flush();

        assertThat(batchService.runPending()).isZero();
    }

    /**
     * 집계는 전체 기간이라 같은 태그가 계속 조건을 넘긴다. 세션마다 같은 관찰을
     * 새로 만들면 <b>발견 화면이 같은 문장으로 도배된다.</b>
     */
    @Test
    @DisplayName("같은 태그로 이미 살아 있는 관찰이 있으면 또 만들지 않는다")
    void doesNotDuplicateActiveObservation() {
        turn(1, "1.50", "회의");
        turn(2, "1.50", "회의");
        turn(3, "1.50", "회의");
        setUserAvgGap("0.80");
        endSession();
        assertThat(batchService.runPending()).isEqualTo(1);

        UUID second = sessionRepository.save(
                VoiceSession.start(profileId, "fixed", new BigDecimal("0.85"))).getId();
        em.flush();
        jdbc.update("update voice_session set ended_at = ?, duration_sec = 120 where id = ?",
                Timestamp.from(Instant.now()), second);
        em.clear();

        assertThat(batchService.runPending()).isZero();
        assertThat(observationsOfProfile()).hasSize(1);
    }

    // ── 도구 ────────────────────────────────────────────────────────

    private void turn(int turnIndex, String gap, String tag) {
        UUID turnId = UUID.randomUUID();
        em.flush();
        jdbc.update("insert into turn_log (id, session_id, turn_index, role, occurred_at, transcript_enc, gap)"
                        + " values (?, ?, ?, 'user', ?, 'enc-placeholder', ?)",
                turnId, sessionId, turnIndex,
                Timestamp.from(Instant.now().plusSeconds(turnIndex)),
                gap == null ? null : new BigDecimal(gap));
        jdbc.update("insert into turn_tag (turn_id, tag) values (?, ?)", turnId, tag);
        em.clear();
    }

    private void setUserAvgGap(String avgGap) {
        em.flush();
        jdbc.update("update user_baseline set avg_gap = ? where profile_id = ?",
                new BigDecimal(avgGap), profileId);
        em.clear();
    }

    private void endSession() {
        em.flush();
        jdbc.update("update voice_session set ended_at = ?, duration_sec = 180 where id = ?",
                Timestamp.from(Instant.now()), sessionId);
        em.clear();
    }

    private List<Observation> observationsOfProfile() {
        em.flush();
        return observationRepository.findAll().stream()
                .filter(o -> o.getProfileId().equals(profileId))
                .toList();
    }
}
