package com.hackathonyaho.voicejournal.session.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 계약 §3-4. AI서버의 <b>CLM 인증을 겸한다</b> — 이 응답이 늦거나 죽으면 AI가
 * fail-closed로 401을 돌려주므로 <b>새 대화가 시작되지 않는다</b>.
 *
 * <p>발화 텍스트류는 넣지 않는다.
 */
public record InternalSessionResponse(
        UUID sessionId,
        String status,
        Instant startedAt,
        int usedSec,
        int lastTurnIndex,
        String thresholdMode,
        BigDecimal gapThreshold,
        int softWrapSec,
        int hardCutSec,
        boolean demoMode,
        List<Observation> recentObservations) {

    /** Phase 4 전에는 항상 빈 배열이다 — 관찰이 아직 없으므로 정상이다. */
    public record Observation(String observationId, String tag, String sentence) {
    }
}
