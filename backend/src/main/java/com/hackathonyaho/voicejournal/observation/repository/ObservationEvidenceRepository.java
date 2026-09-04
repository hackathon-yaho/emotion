package com.hackathonyaho.voicejournal.observation.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/** 관찰 ↔ 근거 턴 연결. 조회는 turn ID만 가져오고 본문은 엔티티가 복호화한다. */
@Component
@RequiredArgsConstructor
public class ObservationEvidenceRepository {

    private final JdbcTemplate jdbc;

    public List<UUID> turnIdsOf(UUID observationId) {
        return jdbc.queryForList(
                "select turn_id from observation_evidence where observation_id = ?",
                UUID.class, observationId);
    }
}
