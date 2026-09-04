package com.hackathonyaho.voicejournal.observation.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 계약 §2-7. <b>{@code turns} 길이는 {@code evidence.occurrences}와 반드시 같다</b> —
 * 다르면 계약 위반이고 §1.4의 "evidence 불일치 0건" 지표 실패로 집계한다.
 *
 * <p>이 화면이 P0인 이유는 그 지표를 <b>증명할 수단</b>이기 때문이다. 스코프 컷에서도
 * 자르지 않는다(spec §11).
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record ObservationEvidenceResponse(
        String observationId,
        String sentence,
        ObservationListResponse.Evidence evidence,
        List<Turn> turns) {

    public record Turn(
            UUID turnId,
            UUID sessionId,
            Instant occurredAt,
            String transcript,
            BigDecimal textValence,
            BigDecimal voiceValence,
            BigDecimal gap) {
    }
}
