package com.hackathonyaho.voicejournal.session.dto.response;

import java.util.UUID;

/**
 * 계약 §2-14. 동시 접속 정원이 찼을 때의 대기 순번.
 *
 * <p><b>{@code position}이 0이면 {@code session}이 들어 있고, 그 응답 자체가 입장권이다.</b>
 * 자리를 미리 예약해 두지 않으므로 만료 타이머도, 가로채기도 없다 — 줄 맨 앞 한 명만
 * 받아 갈 수 있다.
 */
public record SessionQueueResponse(
        UUID ticketId,
        int position,
        int pollIntervalSec,
        SessionStartResponse session) {

    public static SessionQueueResponse waiting(UUID ticketId, int position, int pollIntervalSec) {
        return new SessionQueueResponse(ticketId, position, pollIntervalSec, null);
    }

    public static SessionQueueResponse admitted(UUID ticketId, int pollIntervalSec, SessionStartResponse session) {
        return new SessionQueueResponse(ticketId, 0, pollIntervalSec, session);
    }
}
