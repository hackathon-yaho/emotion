package com.hackathonyaho.voicejournal.session.dto.response;

import java.util.List;
import java.util.UUID;

/**
 * 계약 §2-11. <b>앱은 이 응답을 받으면 관찰 목록 캐시를 무효화한다</b> — 근거를 잃은
 * 관찰이 화면에 남아 있으면 그 순간 "근거 없는 문장"이 된다(FR-081).
 */
public record SessionDeleteResponse(
        UUID deletedSessionId,
        int deletedTurnCount,
        /** 남은 근거가 3회 미만이 되어 <b>삭제된</b> 관찰. */
        List<String> removedObservationIds,
        /** 근거는 남았으나 <b>숫자가 재계산된</b> 관찰. */
        List<String> recalculatedObservationIds) {
}
