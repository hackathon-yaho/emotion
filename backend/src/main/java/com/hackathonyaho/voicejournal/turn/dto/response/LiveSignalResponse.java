package com.hackathonyaho.voicejournal.turn.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * 계약 §2-13. S02에서만 폴링한다.
 *
 * <p><b>{@code transcript}를 담지 않는다</b> — 앱은 EVI에서 이미 텍스트를 받고 있어
 * 불필요하고, 노출면만 늘어난다.
 *
 * <p><b>{@code turns}는 데모 모드에서만 채운다.</b> FR-031 방어선이 여기서 이중이 된다 —
 * 앱이 S02에 갭을 그리지 않는 것이 1차, 서버가 아예 주지 않는 것이 2차다.
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record LiveSignalResponse(
        UUID sessionId,
        int lastTurnIndex,
        boolean crisisDetected,
        List<Turn> turns) {

    public record Turn(
            int turnIndex,
            BigDecimal textValence,
            BigDecimal voiceValence,
            BigDecimal gap,
            boolean gapTriggered) {
    }
}
