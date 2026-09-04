package com.hackathonyaho.voicejournal.observation.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * 계약 §2-6.
 *
 * <p><b>{@code evidence}는 목록에서도 반드시 함께 내려간다</b> — 관찰 문장만 있고 근거가
 * 없는 상태를 계약 수준에서 만들지 않는다(FR-053).
 *
 * <p>관찰이 없으면 <b>빈 배열</b>이다. "아직 없어요" 안내는 앱이 하고 서버가 억지 문구를
 * 만들지 않는다(계약 §1-3).
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record ObservationListResponse(long total, List<Item> observations) {

    public record Item(
            String observationId,
            Instant createdAt,
            String sentence,
            Evidence evidence,
            String feedback) {
    }

    /** 다섯 키가 그대로 계약 §2-6의 evidence다. <b>turn ID를 넣지 않는다.</b> */
    public record Evidence(
            String tag,
            int occurrences,
            BigDecimal tagAvgGap,
            BigDecimal userAvgGap,
            BigDecimal ratio) {
    }
}
