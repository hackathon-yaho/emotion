package com.hackathonyaho.voicejournal.turn.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 계약 §3-2. AI서버 → 백엔드. <b>음성 원본은 필드 자체가 없다</b>(FR-041).
 *
 * <p>받아서 그대로 저장한다 — 백엔드는 valence·갭·태그·위기를 재계산하거나 재검증하지
 * 않는다. {@code thresholdMode}는 세션 단위 값이라 {@code voice_session}에 이미 있어
 * 받더라도 {@code turn_log}에 중복 저장하지 않는다.
 */
public record TurnIngestRequest(
        @NotNull(message = "sessionId는 필수입니다.")
        UUID sessionId,

        @NotNull(message = "turnIndex는 필수입니다.")
        Integer turnIndex,

        @NotBlank(message = "role은 필수입니다.")
        String role,

        /**
         * <b>발화 시각.</b> 재시도는 최초 시도와 같은 값을 보낸다(계약 §3-2 v1.5) —
         * {@code unique(session_id, turn_index)} 충돌을 "재시도"와 "다른 발화"로
         * 가르는 기준이 이 필드다.
         */
        @NotNull(message = "occurredAt은 필수입니다.")
        Instant occurredAt,

        @NotNull(message = "transcript는 필수입니다.")
        String transcript,

        /** assistant 턴과 분석 실패 턴(TC-06)에서는 전부 null로 온다. */
        BigDecimal textValence,
        BigDecimal voiceValence,
        BigDecimal gap,
        Boolean gapTriggered,
        String thresholdMode,
        List<String> tags,
        Map<String, Double> topProsody,
        Crisis crisis) {

    /** {@code turn_log}에 저장하지 않는다 — {@code crisis_event}로만 간다. */
    public record Crisis(Boolean detected, String by) {
    }

    public boolean gapTriggeredOrFalse() {
        return Boolean.TRUE.equals(gapTriggered);
    }

    public boolean crisisDetected() {
        return crisis != null && Boolean.TRUE.equals(crisis.detected());
    }

    /** 규칙이 죽어도 LLM 경로가 남아야 하므로, 값이 없으면 규칙으로 본다 (F4). */
    public String crisisDetectedBy() {
        return crisis == null || crisis.by() == null || crisis.by().isBlank() ? "rule" : crisis.by();
    }
}
