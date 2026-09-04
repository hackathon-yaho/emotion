package com.hackathonyaho.voicejournal.session.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** 계약 §2-4. 앱은 이 응답만으로 EVI에 연결한다. */
public record SessionStartResponse(
        UUID sessionId,
        String humeAccessToken,
        Instant humeTokenExpiresAt,
        String humeConfigId,
        String thresholdMode,
        BigDecimal gapThreshold,
        int softWrapSec,
        int hardCutSec,
        int livePollIntervalSec,
        boolean demoMode) {
}
