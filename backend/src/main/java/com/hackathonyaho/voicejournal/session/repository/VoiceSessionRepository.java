package com.hackathonyaho.voicejournal.session.repository;

import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface VoiceSessionRepository extends JpaRepository<VoiceSession, UUID> {

    /** 한 사용자에게 열린 세션은 하나여야 한다 — 시작할 때마다 먼저 닫는다(F2-06 부수 효과). */
    Optional<VoiceSession> findFirstByProfileIdAndEndedAtIsNullOrderByStartedAtDesc(UUID profileId);

    List<VoiceSession> findByProfileIdAndEndedAtIsNull(UUID profileId);

    /** F2-06 스케줄러 — 열린 세션만 훑는다. 부분 인덱스 {@code idx_session_open}가 받는다. */
    List<VoiceSession> findByEndedAtIsNull();
}
