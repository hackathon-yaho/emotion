package com.hackathonyaho.voicejournal.session.repository;

import com.hackathonyaho.voicejournal.common.global.Paging;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** 대화 기록 목록·상세의 집계 (F9-04·05). */
@Component
@RequiredArgsConstructor
public class SessionHistoryRepository {

    /** 그 세션 상위 3개까지 (계약 §2-9). */
    private static final int TOP_TAGS = 3;

    private final JdbcTemplate jdbc;

    /** 계약 §1-1 — 소수 2자리. {@code avg()}가 주는 큰 스케일을 그대로 내보내지 않는다. */
    private static BigDecimal round(BigDecimal value) {
        return value == null ? null : value.setScale(2, java.math.RoundingMode.HALF_UP);
    }

    /** {@code = any(?)}는 드라이버가 UUID 배열 타입을 추론하지 못한다. 자리표시로 편다. */
    private static String placeholders(int count) {
        return String.join(", ", java.util.Collections.nCopies(count, "?"));
    }

    public record SessionSummary(UUID sessionId, Instant startedAt, int durationSec, int turnCount,
                                 String summary, BigDecimal gapAvg) {
    }

    /**
     * <b>끝난 세션만 기록이다.</b> 진행 중인 대화가 목록에 뜨면 사용자는 그것을 "지난
     * 대화"로 읽는다 — 이어하기 제안은 {@code GET /api/me}의 {@code openSession}이 한다.
     */
    public List<SessionSummary> list(UUID profileId, Paging paging) {
        return jdbc.query(
                "select s.id, s.started_at, s.duration_sec, s.summary, "
                        + "       (select count(*) from turn_log t where t.session_id = s.id) as turn_count, "
                        + "       (select avg(t.gap) from turn_log t "
                        + "         where t.session_id = s.id and t.gap is not null) as gap_avg "
                        + "from voice_session s "
                        + "where s.profile_id = ? and s.ended_at is not null "
                        + "order by s.started_at desc "
                        + "limit ? offset ?",
                (rs, rowNum) -> new SessionSummary(
                        rs.getObject("id", UUID.class),
                        rs.getTimestamp("started_at").toInstant(),
                        rs.getInt("duration_sec"),
                        rs.getInt("turn_count"),
                        rs.getString("summary"),
                        round(rs.getBigDecimal("gap_avg"))),
                profileId, paging.limit(), paging.offset());
    }

    public long countEnded(UUID profileId) {
        Long count = jdbc.queryForObject(
                "select count(*) from voice_session where profile_id = ? and ended_at is not null",
                Long.class, profileId);
        return count == null ? 0 : count;
    }

    /** 세션마다 따로 묻지 않는다 — 목록 한 번에 쿼리가 20개 더 나가는 것을 막는다. */
    public Map<UUID, List<String>> topTagsFor(List<UUID> sessionIds) {
        if (sessionIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, List<String>> result = new HashMap<>();
        jdbc.query(
                "select t.session_id, tt.tag, count(*) as c "
                        + "from turn_tag tt join turn_log t on t.id = tt.turn_id "
                        + "where t.session_id in (" + placeholders(sessionIds.size()) + ") "
                        + "group by t.session_id, tt.tag "
                        + "order by t.session_id, c desc",
                rs -> {
                    UUID sessionId = rs.getObject("session_id", UUID.class);
                    List<String> tags = result.computeIfAbsent(sessionId, k -> new ArrayList<>());
                    if (tags.size() < TOP_TAGS) {
                        tags.add(rs.getString("tag"));
                    }
                },
                sessionIds.toArray());
        return result;
    }

    public Map<UUID, List<String>> tagsForTurns(List<UUID> turnIds) {
        if (turnIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, List<String>> result = new HashMap<>();
        jdbc.query(
                "select turn_id, tag from turn_tag "
                        + "where turn_id in (" + placeholders(turnIds.size()) + ") order by turn_id, tag",
                rs -> {
                    UUID turnId = rs.getObject("turn_id", UUID.class);
                    result.computeIfAbsent(turnId, k -> new ArrayList<>()).add(rs.getString("tag"));
                },
                turnIds.toArray());
        return result;
    }
}
