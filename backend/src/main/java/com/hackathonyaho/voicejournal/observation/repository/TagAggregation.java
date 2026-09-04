package com.hackathonyaho.voicejournal.observation.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * 태그별 집계 (F7-02). <b>사용자 전체 기간</b>이 대상이다 — 이번 세션만이 아니다.
 *
 * <p><b>갭이 NULL인 턴은 전부 제외한다.</b> 분석이 실패한 턴(TC-06)은 갭이 없는데,
 * 그걸 0으로 세면 평균이 내려가 조건을 넘기지 못하거나 반대로 비율이 부풀려진다.
 */
@Component
@RequiredArgsConstructor
public class TagAggregation {

    private final JdbcTemplate jdbc;

    /** 태그 하나의 집계. {@code userAvgGap}은 여기서 계산하지 않는다 — 아래 참조. */
    public record TagStat(String tag, int occurrences, BigDecimal tagAvgGap) {
    }

    /**
     * <b>{@code userAvgGap}을 여기서 다시 계산하지 않는다.</b> 그 값은
     * {@code user_baseline.avg_gap} 하나이고, 관찰의 evidence·트렌드 응답(§2-8)이
     * 전부 같은 값을 읽어야 한다. 조회 시점마다 다시 계산하는 코드를 만들면
     * <b>§1.4 "evidence 불일치 0건"이 그 순간 깨진다.</b>
     */
    public List<TagStat> tagStatsFor(UUID profileId) {
        return jdbc.query(
                "select tt.tag, count(*) as occurrences, avg(t.gap) as tag_avg_gap "
                        + "from turn_tag tt "
                        + "         join turn_log t on t.id = tt.turn_id "
                        + "         join voice_session s on s.id = t.session_id "
                        + "where s.profile_id = ? and t.gap is not null "
                        + "group by tt.tag",
                (rs, rowNum) -> new TagStat(rs.getString("tag"), rs.getInt("occurrences"),
                        rs.getBigDecimal("tag_avg_gap")),
                profileId);
    }

    /**
     * 그 태그로 센 턴들. <b>집계에 쓴 것과 같은 조건이어야 한다</b> — 아니면
     * {@code occurrences}와 실제 근거 건수가 어긋나 TC-17이 깨진다.
     */
    public List<UUID> evidenceTurnIds(UUID profileId, String tag) {
        return jdbc.queryForList(
                "select t.id "
                        + "from turn_tag tt "
                        + "         join turn_log t on t.id = tt.turn_id "
                        + "         join voice_session s on s.id = t.session_id "
                        + "where s.profile_id = ? and tt.tag = ? and t.gap is not null",
                UUID.class, profileId, tag);
    }

    public void linkEvidence(UUID observationId, List<UUID> turnIds) {
        jdbc.batchUpdate(
                "insert into observation_evidence (observation_id, turn_id) values (?, ?) on conflict do nothing",
                turnIds.stream().map(turnId -> new Object[]{observationId, turnId}).toList());
    }
}
