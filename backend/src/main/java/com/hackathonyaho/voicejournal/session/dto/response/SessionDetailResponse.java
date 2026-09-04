package com.hackathonyaho.voicejournal.session.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 계약 §2-10. <b>턴 배열만이 아니다</b> — 상단의 `endedAt`·`endReason`·`thresholdMode`·
 * `summary`도 함께 내려간다.
 *
 * <p><b>갭 수치가 여기서는 노출된다.</b> 대화 화면(S02)과 구분되는 지점이다(FR-031) —
 * 기록은 돌아보는 화면이라 수치가 관찰당하는 느낌을 주지 않는다.
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record SessionDetailResponse(
        UUID sessionId,
        Instant startedAt,
        Instant endedAt,
        Integer durationSec,
        String endReason,
        String thresholdMode,
        String summary,
        List<Turn> turns) {

    /** assistant 턴은 valence·gap이 전부 null, tags는 빈 배열이다 — 저장된 그대로. */
    public record Turn(
            UUID turnId,
            int turnIndex,
            Instant occurredAt,
            String role,
            String transcript,
            BigDecimal textValence,
            BigDecimal voiceValence,
            BigDecimal gap,
            boolean gapTriggered,
            List<String> tags) {
    }
}
