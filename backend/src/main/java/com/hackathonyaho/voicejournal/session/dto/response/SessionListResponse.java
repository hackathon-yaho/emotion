package com.hackathonyaho.voicejournal.session.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** 계약 §2-9. 최신순 고정(§1-4). `tags`는 그 세션 상위 3개까지. */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record SessionListResponse(long total, List<Item> sessions) {

    public record Item(
            UUID sessionId,
            Instant startedAt,
            int durationSec,
            int turnCount,
            String summary,
            BigDecimal gapAvg,
            List<String> tags) {
    }
}
