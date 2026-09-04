package com.hackathonyaho.voicejournal.session.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** 계약 §2-5-1 (P1). {@code remainingSec}는 새 7분이 아니라 잔여분이다 — PRD NFR-06. */
public record SessionResumeResponse(
        UUID sessionId,
        String humeAccessToken,
        Instant humeTokenExpiresAt,
        String humeConfigId,
        String resumedChatGroupId,
        int remainingSec,
        String thresholdMode,
        BigDecimal gapThreshold,
        boolean demoMode) {
}
