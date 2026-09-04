package com.hackathonyaho.voicejournal.turn.repository;

import com.hackathonyaho.voicejournal.turn.entity.TurnLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TurnLogRepository extends JpaRepository<TurnLog, UUID> {

    /** 중복 판별용 — 위반이 난 경로에서만 부른다 (3-1). */
    Optional<TurnLog> findBySessionIdAndTurnIndex(UUID sessionId, int turnIndex);

    /** {@code /live}의 `sinceTurnIndex` — 그 이후 턴만 (계약 §2-13). */
    List<TurnLog> findBySessionIdAndTurnIndexGreaterThanOrderByTurnIndex(UUID sessionId, int turnIndex);

    /** 요약 생성용 (계약 §3-5). 변환기가 복호화하므로 transcript는 평문으로 나온다. */
    List<TurnLog> findBySessionIdOrderByTurnIndex(UUID sessionId);
}
