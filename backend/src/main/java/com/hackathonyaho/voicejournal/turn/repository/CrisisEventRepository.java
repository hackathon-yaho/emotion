package com.hackathonyaho.voicejournal.turn.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * 위기 감지 적재 (F4). <b>{@code turn_id}를 두지 않는다</b>(백엔드 절대 원칙 2번) —
 * 위기 이벤트에서 그 발화로 도달하는 경로를 가장 민감한 지점에서 아예 만들지 않는다.
 * 발화 내용도 담지 않는다.
 */
@Component
@RequiredArgsConstructor
public class CrisisEventRepository {

    private final JdbcTemplate jdbc;

    public void save(UUID profileId, UUID sessionId, String detectedBy) {
        jdbc.update("insert into crisis_event (profile_id, session_id, detected_by) values (?, ?, ?)",
                profileId, sessionId, detectedBy);
    }

    /** 세션 단위 boolean이다 — 턴에 묶지 않는다 (계약 §2-13). */
    public boolean existsForSession(UUID sessionId) {
        Boolean found = jdbc.queryForObject(
                "select exists(select 1 from crisis_event where session_id = ?)", Boolean.class, sessionId);
        return Boolean.TRUE.equals(found);
    }
}
