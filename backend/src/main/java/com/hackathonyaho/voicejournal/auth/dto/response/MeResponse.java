package com.hackathonyaho.voicejournal.auth.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.UUID;

/**
 * 계약 §2-2. 홈(S01)과 설정(S06)이 공용으로 쓴다.
 *
 * <p>{@code thresholdMode}는 표시용이다 — 실제 적용 값은 세션 시작 시 다시 내려간다(§2-4).
 * {@code openSession}은 Phase 2에서 채운다.
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record MeResponse(
        UUID profileId,
        Instant joinedAt,
        int sessionCount,
        String thresholdMode,
        boolean demoMode,
        OpenSession openSession) {

    /** 비정상 중단으로 열려 있는 세션. 없으면 null (Phase 2). */
    public record OpenSession(
            UUID sessionId,
            Instant startedAt,
            int usedSec,
            int remainingSec,
            Instant resumableUntil) {
    }
}
