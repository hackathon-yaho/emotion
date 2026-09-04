package com.hackathonyaho.voicejournal.session.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

/**
 * {@code turn_log} 집계만 읽는다. 엔티티를 만들지 않는 이유는 Phase 2가 <b>본문을 한 글자도
 * 읽지 않기</b> 때문이다 — 평문이 필요한 순간은 복호화 변환기가 붙는 Phase 3다.
 */
@Component
@RequiredArgsConstructor
public class TurnStats {

    private final JdbcTemplate jdbc;

    /**
     * 계약 §3-4 {@code lastTurnIndex} — <b>"적재된 최대 turnIndex"이지 "적재 건수"가 아니다.</b>
     * 4xx로 버려진 턴이 있으면 두 값이 갈리고, AI서버가 이 값 다음부터 채번을 이어 붙인다.
     */
    public int lastTurnIndex(UUID sessionId) {
        Integer max = jdbc.queryForObject(
                "select coalesce(max(turn_index), 0) from turn_log where session_id = ?",
                Integer.class, sessionId);
        return max == null ? 0 : max;
    }

    public int turnCount(UUID sessionId) {
        Integer count = jdbc.queryForObject(
                "select count(*) from turn_log where session_id = ?", Integer.class, sessionId);
        return count == null ? 0 : count;
    }

    /** 갭이 NULL인 턴은 제외한다(계약 §2-5). 전부 NULL이면 결과도 null이다. */
    public BigDecimal avgGap(UUID sessionId) {
        return jdbc.queryForObject(
                "select avg(gap) from turn_log where session_id = ? and gap is not null",
                BigDecimal.class, sessionId);
    }

    /**
     * <b>마지막으로 말한 시각.</b> 앱이 죽으면 종료 신호가 오지 않으므로 서버가 아는
     * 마지막 활동은 이것뿐이다 — 이어하기 창과 F2-06 정리가 모두 여기서 갈린다.
     *
     * <p>턴이 없으면 {@code startedAt}이다: 시작만 하고 말하지 않은 세션이다.
     */
    public Instant lastActivityAt(UUID sessionId, Instant startedAt) {
        Timestamp last = jdbc.queryForObject(
                "select max(occurred_at) from turn_log where session_id = ?",
                Timestamp.class, sessionId);
        return last == null ? startedAt : last.toInstant();
    }
}
