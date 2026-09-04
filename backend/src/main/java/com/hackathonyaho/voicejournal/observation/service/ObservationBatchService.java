package com.hackathonyaho.voicejournal.observation.service;

import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.common.global.SessionRef;
import com.hackathonyaho.voicejournal.common.ops.OpsErrorLogger;
import com.hackathonyaho.voicejournal.observation.entity.Observation;
import com.hackathonyaho.voicejournal.observation.repository.ObservationRepository;
import com.hackathonyaho.voicejournal.observation.repository.TagAggregation;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * 패턴 배치 (F7-01~05). 스케줄러가 부른다.
 *
 * <p><b>판정은 코드가 한다.</b> 여기에 LLM 호출을 섞지 않는다 — 로그를 통째로 주면
 * LLM은 그럴듯한 패턴을 <b>반드시</b> 만들어낸다(FR-051·052·054). AI서버는 판정을
 * 통과한 숫자를 <b>문장으로 바꾸는 일만</b> 한다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ObservationBatchService {

    /** F7-03 — 이 둘을 동시에 넘겨야 관찰이 생긴다. 미달이면 침묵한다. */
    private static final int MIN_OCCURRENCES = 3;
    private static final BigDecimal MIN_RATIO = new BigDecimal("1.5");

    private final VoiceSessionRepository sessionRepository;
    private final UserBaselineRepository baselineRepository;
    private final ObservationRepository observationRepository;
    private final TagAggregation tagAggregation;
    private final ObservationSentenceClient sentenceClient;
    private final OpsErrorLogger opsErrorLogger;

    /**
     * 미처리 세션을 훑는다. <b>실패는 그 세션에서 삼키고 다음으로 넘어간다</b> —
     * 배치 실패가 대화·조회에 영향을 주면 안 된다(F7-01 수용 기준).
     *
     * <p>실패한 세션은 {@code pattern_processed_at}이 NULL로 남아 <b>다음 주기에 자동
     * 재시도</b>된다. 별도 재시도 카운터를 두지 않는다 — 계속 실패하면
     * {@code ops_error_log}에 반복해 남으므로 그것으로 알아챈다.
     */
    @Transactional
    public int runPending() {
        List<VoiceSession> pending = sessionRepository.findByEndedAtIsNotNullAndPatternProcessedAtIsNull();

        // 같은 사용자의 세션이 여럿 밀려 있어도 집계는 전체 기간이라 한 번이면 된다.
        // 두 번 돌리면 AI 호출만 두 배가 된다.
        Set<UUID> done = new HashSet<>();
        int created = 0;

        for (VoiceSession session : pending) {
            try {
                if (done.add(session.getProfileId())) {
                    created += createObservationsFor(session.getProfileId());
                }
                session.markPatternProcessed();
            } catch (Exception e) {
                // 발화·sessionId를 남기지 않는다. 이 세션은 NULL로 남아 다음 주기에 다시 온다.
                opsErrorLogger.log("backend", "PATTERN_BATCH_FAILED",
                        "sessionRef=%s cause=%s".formatted(
                                SessionRef.of(session.getId().toString()), e.getClass().getSimpleName()));
            }
        }
        return created;
    }

    private int createObservationsFor(UUID profileId) {
        UserBaseline baseline = baselineRepository.findById(profileId).orElse(null);
        if (baseline == null || baseline.getAvgGap() == null
                || baseline.getAvgGap().compareTo(BigDecimal.ZERO) == 0) {
            // 갭이 한 건도 없거나 평균이 0이면 비율을 낼 수 없다. 억지로 만들지 않는다.
            return 0;
        }
        BigDecimal userAvgGap = baseline.getAvgGap();
        BigDecimal threshold = userAvgGap.multiply(MIN_RATIO);

        int created = 0;
        for (TagAggregation.TagStat stat : tagAggregation.tagStatsFor(profileId)) {
            if (!passes(stat, threshold)) {
                continue;
            }
            // 같은 태그로 이미 살아 있는 관찰이 있으면 만들지 않는다 — 아래 주의.
            if (observationRepository.existsByProfileIdAndTagAndStatus(profileId, stat.tag(), Observation.ACTIVE)) {
                continue;
            }
            if (createObservation(profileId, stat, userAvgGap)) {
                created++;
            }
        }
        return created;
    }

    /**
     * F7-03 — {@code occurrences >= 3} <b>AND</b> {@code tagAvgGap >= userAvgGap × 1.5}.
     *
     * <p><b>미달이면 아무것도 만들지 않는다.</b> 데이터가 부족한 사용자에게 관찰이 안
     * 생기는 것은 버그가 아니라 사양이다(TC-16) — <b>침묵할 수 있어야 말할 때 믿긴다.</b>
     */
    private boolean passes(TagAggregation.TagStat stat, BigDecimal threshold) {
        return stat.occurrences() >= MIN_OCCURRENCES
                && stat.tagAvgGap() != null
                && stat.tagAvgGap().compareTo(threshold) >= 0;
    }

    private boolean createObservation(UUID profileId, TagAggregation.TagStat stat, BigDecimal userAvgGap) {
        BigDecimal ratio = stat.tagAvgGap().divide(userAvgGap, 2, RoundingMode.HALF_UP);
        BigDecimal tagAvgGap = stat.tagAvgGap().setScale(2, RoundingMode.HALF_UP);

        String sentence = sentenceClient.sentenceFor(
                stat.tag(), stat.occurrences(), tagAvgGap, userAvgGap, ratio);
        if (sentence == null) {
            // 문장이 없으면 관찰도 없다. 템플릿으로 채우지 않는다.
            return false;
        }

        Observation observation = observationRepository.saveAndFlush(Observation.of(
                profileId, sentence, stat.tag(), stat.occurrences(), tagAvgGap, userAvgGap, ratio));

        // 집계에 쓴 것과 같은 조건으로 근거 턴을 잇는다 — 어긋나면 TC-17이 깨진다.
        tagAggregation.linkEvidence(observation.getId(), tagAggregation.evidenceTurnIds(profileId, stat.tag()));
        return true;
    }
}
