package com.hackathonyaho.voicejournal.trend.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * 트렌드 집계 (F9). <b>일자 경계는 KST다</b>(계약 §1-1) — 저장은 UTC이므로 변환한다.
 * 사용자가 체감하는 "하루"가 기준이어야 트렌드가 맞다: 새벽 1시 대화는 그 전날에
 * 속한다고 느껴진다.
 *
 * <p><b>갭이 NULL인 턴은 전부 뺀다.</b> 계약 §1-3이 "측정하지 못했다"로 못 박은 값이라,
 * 0으로 세면 없는 감정을 그리게 된다.
 */
@Component
@RequiredArgsConstructor
public class TrendRepository {

    private static final String KST = "Asia/Seoul";

    private final JdbcTemplate jdbc;

    /** 하루치 집계. 하루에 2세션 이상이면 그날의 평균이고 {@code sessionCount}로 표시한다. */
    public record DayPoint(LocalDate date, BigDecimal textValence, BigDecimal voiceValence,
                           BigDecimal gap, int sessionCount, BigDecimal dayThreshold) {
    }

    public record TagGap(String tag, int occurrences, BigDecimal tagAvgGap) {
    }

    /**
     * <b>{@code dayThreshold}는 그날 세션에 실제로 적용됐던 값이다</b>(스냅샷) —
     * `.env`의 현재값이 아니다. 현재값으로 소급 판정하면 임계값을 확정하는 순간
     * 과거 날짜의 음영이 통째로 달라져, 그날 앱이 실제로 되물었던 근거(FR-022)와
     * 화면이 어긋난다.
     */
    public List<DayPoint> dailyPoints(UUID profileId, Instant from) {
        return jdbc.query(
                "select (t.occurred_at at time zone ?)::date as d, "
                        + "       avg(t.text_valence) as text_valence, "
                        + "       avg(t.voice_valence) as voice_valence, "
                        + "       avg(t.gap) as gap, "
                        + "       count(distinct t.session_id) as session_count, "
                        + "       avg(s.gap_threshold) as day_threshold "
                        + "from turn_log t "
                        + "         join voice_session s on s.id = t.session_id "
                        + "where s.profile_id = ? and t.occurred_at >= ? and t.gap is not null "
                        + "group by d "
                        + "order by d",
                (rs, rowNum) -> new DayPoint(
                        rs.getObject("d", java.sql.Date.class).toLocalDate(),
                        rs.getBigDecimal("text_valence"),
                        rs.getBigDecimal("voice_valence"),
                        rs.getBigDecimal("gap"),
                        rs.getInt("session_count"),
                        rs.getBigDecimal("day_threshold")),
                KST, profileId, Timestamp.from(from));
    }

    /**
     * F9-03 (P1). <b>{@code range}에 종속된다</b> — 전 기간이 아니다.
     * 등장 3회 미만은 서버가 걸러내고(F7-03과 같은 기준), 상위 7개까지.
     */
    public List<TagGap> tagGaps(UUID profileId, Instant from) {
        return jdbc.query(
                "select tt.tag, count(*) as occurrences, avg(t.gap) as tag_avg_gap "
                        + "from turn_tag tt "
                        + "         join turn_log t on t.id = tt.turn_id "
                        + "         join voice_session s on s.id = t.session_id "
                        + "where s.profile_id = ? and t.occurred_at >= ? and t.gap is not null "
                        + "group by tt.tag "
                        + "having count(*) >= 3 "
                        + "order by avg(t.gap) desc "
                        + "limit 7",
                (rs, rowNum) -> new TagGap(rs.getString("tag"), rs.getInt("occurrences"),
                        rs.getBigDecimal("tag_avg_gap")),
                profileId, Timestamp.from(from));
    }
}
