package com.hackathonyaho.voicejournal.session.service;

import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.session.dto.response.SessionDeleteResponse;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.TurnStats;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 대화 삭제와 관찰 연쇄 무효화 (F10-01·02). 순서는 {@code data-model.md} "삭제 순서"다.
 *
 * <p><b>전 과정이 단일 트랜잭션이다.</b> 중간에 실패하면 "절반만 지워진" 상태가 남는다.
 * FK가 {@code NO ACTION}이라 순서를 어기면 제약 위반으로 즉시 실패하고 롤백된다 —
 * <b>순서 실수가 조용히 넘어가지 않는다는 뜻이라 오히려 안전하다.</b>
 */
@Service
@RequiredArgsConstructor
public class SessionDeletionService {

    /** F7-03의 생성 조건과 같은 값이다 — 생성될 수 없었을 관찰이 삭제 후에 살아남으면 안 된다. */
    private static final int MIN_OCCURRENCES = 3;

    private final JdbcTemplate jdbc;
    private final SessionService sessionService;
    private final UserBaselineRepository baselineRepository;
    private final TurnStats turnStats;

    @Transactional
    public SessionDeleteResponse delete(UUID profileId, UUID sessionId) {
        VoiceSession session = sessionService.requireOwned(profileId, sessionId);

        // ① 영향받는 관찰을 먼저 모은다. ④에서 턴을 지우면 연결이 사라져
        //    "어느 관찰이 영향받았는지"를 알 방법이 없어진다.
        List<UUID> affected = jdbc.queryForList(
                "select distinct e.observation_id from observation_evidence e "
                        + "join turn_log t on t.id = e.turn_id where t.session_id = ?",
                UUID.class, sessionId);

        // ②③ 턴에 매달린 것부터 끊는다.
        jdbc.update("delete from turn_tag where turn_id in (select id from turn_log where session_id = ?)",
                sessionId);
        jdbc.update("delete from observation_evidence "
                + "where turn_id in (select id from turn_log where session_id = ?)", sessionId);

        // ④
        int deletedTurnCount = jdbc.update("delete from turn_log where session_id = ?", sessionId);

        // ⑥⑦ crisis_event는 session_id를 FK로 갖고 있어 이걸 남기면 ⑦이 제약 위반으로 실패한다.
        jdbc.update("delete from crisis_event where session_id = ?", sessionId);
        jdbc.update("delete from voice_session where id = ?", sessionId);

        // ⑧을 ⑤보다 먼저 한다 — 아래 주의.
        recalculateBaseline(profileId);

        List<UUID> removed = new ArrayList<>();
        List<UUID> recalculated = new ArrayList<>();
        for (UUID observationId : affected) {
            if (settleObservation(observationId, profileId)) {
                removed.add(observationId);
            } else {
                recalculated.add(observationId);
            }
        }

        return new SessionDeleteResponse(session.getId(), deletedTurnCount,
                removed.stream().map(UUID::toString).toList(),
                recalculated.stream().map(UUID::toString).toList());
    }

    /**
     * ⑤ 남은 근거로 관찰을 정리한다. <b>지웠으면 true.</b>
     *
     * <p><b>근거 대화가 삭제됐는데 관찰만 남으면 그 관찰은 그 순간 "근거 없는 문장"이 된다</b> —
     * §1.4 불일치 0건 지표와 직결이다.
     *
     * <p><b>이 분기는 CASCADE로 표현할 수 없다.</b> "미만이면 삭제, 이상이면 재계산"은
     * 조건부라 DB 제약이 아니다 — FK를 {@code NO ACTION}으로 둔 이유이기도 하다.
     */
    private boolean settleObservation(UUID observationId, UUID profileId) {
        List<RemainingEvidence> remaining = jdbc.query(
                "select count(*) as c, avg(t.gap) as g from observation_evidence e "
                        + "join turn_log t on t.id = e.turn_id "
                        + "where e.observation_id = ? and t.gap is not null",
                (rs, rowNum) -> new RemainingEvidence(rs.getInt("c"), rs.getBigDecimal("g")),
                observationId);
        RemainingEvidence evidence = remaining.isEmpty()
                ? new RemainingEvidence(0, null) : remaining.get(0);

        if (evidence.count() < MIN_OCCURRENCES || evidence.avgGap() == null) {
            jdbc.update("delete from observation_evidence where observation_id = ?", observationId);
            jdbc.update("delete from observation where id = ?", observationId);
            return true;
        }

        BigDecimal userAvgGap = baselineRepository.findById(profileId)
                .map(UserBaseline::getAvgGap).orElse(null);
        BigDecimal tagAvgGap = evidence.avgGap().setScale(2, RoundingMode.HALF_UP);

        if (userAvgGap == null || userAvgGap.compareTo(BigDecimal.ZERO) == 0) {
            // 비율을 낼 분모가 사라졌다. 숫자 없는 관찰을 남기지 않는다.
            jdbc.update("delete from observation_evidence where observation_id = ?", observationId);
            jdbc.update("delete from observation where id = ?", observationId);
            return true;
        }

        jdbc.update("update observation set occurrences = ?, tag_avg_gap = ?, user_avg_gap = ?, ratio = ? "
                        + "where id = ?",
                evidence.count(), tagAvgGap, userAvgGap,
                tagAvgGap.divide(userAvgGap, 2, RoundingMode.HALF_UP), observationId);
        return false;
    }

    /**
     * ⑧ — F3-05와 같은 코드다. <b>문서의 순서(⑧이 마지막)와 달리 ⑤보다 먼저 돌린다.</b>
     * ⑤가 {@code ratio}를 다시 계산하는데 그 분모가 이 값이라, 나중에 갱신하면
     * <b>방금 계산한 비율이 옛 평균으로 매겨진 채 남는다.</b> 그러면 관찰의
     * {@code evidence.userAvgGap}과 트렌드의 {@code userAvgGap}이 갈린다.
     */
    private void recalculateBaseline(UUID profileId) {
        TurnStats.Baseline stats = turnStats.baselineFor(profileId);
        baselineRepository.findById(profileId)
                .ifPresent(b -> b.updateGapStats(stats.avgGap(), stats.stddevGap()));
        baselineRepository.flush();
    }

    private record RemainingEvidence(int count, BigDecimal avgGap) {
    }
}
