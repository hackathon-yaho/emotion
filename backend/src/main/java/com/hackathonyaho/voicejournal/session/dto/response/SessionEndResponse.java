package com.hackathonyaho.voicejournal.session.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.util.UUID;

/** 계약 §2-5. {@code summary}·{@code gapAvg}는 null일 수 있다 — 대화 기록 자체는 남는다. */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record SessionEndResponse(
        UUID sessionId,
        int durationSec,
        int turnCount,
        String summary,
        BigDecimal gapAvg) {
}
