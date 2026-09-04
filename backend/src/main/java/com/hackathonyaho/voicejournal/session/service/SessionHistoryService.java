package com.hackathonyaho.voicejournal.session.service;

import com.hackathonyaho.voicejournal.common.global.Paging;
import com.hackathonyaho.voicejournal.session.dto.response.SessionDetailResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionListResponse;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.SessionHistoryRepository;
import com.hackathonyaho.voicejournal.turn.entity.TurnLog;
import com.hackathonyaho.voicejournal.turn.repository.TurnLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/** 대화 기록 조회 (F9-04·05). 응답 필드의 단일 출처는 계약 §2-9·§2-10이다. */
@Service
@RequiredArgsConstructor
public class SessionHistoryService {

    private final SessionHistoryRepository historyRepository;
    private final TurnLogRepository turnLogRepository;
    private final SessionService sessionService;

    @Transactional(readOnly = true)
    public SessionListResponse list(UUID profileId, Paging paging) {
        List<SessionHistoryRepository.SessionSummary> rows = historyRepository.list(profileId, paging);
        // 세션마다 태그 쿼리를 돌리면 목록 하나에 20번이 더 나간다 — 한 번에 가져와 나눈다.
        Map<UUID, List<String>> topTags = historyRepository.topTagsFor(
                rows.stream().map(SessionHistoryRepository.SessionSummary::sessionId).toList());

        return new SessionListResponse(
                historyRepository.countEnded(profileId),
                rows.stream()
                        .map(r -> new SessionListResponse.Item(
                                r.sessionId(), r.startedAt(), r.durationSec(), r.turnCount(),
                                r.summary(), r.gapAvg(), topTags.getOrDefault(r.sessionId(), List.of())))
                        .toList());
    }

    @Transactional(readOnly = true)
    public SessionDetailResponse detail(UUID profileId, UUID sessionId) {
        VoiceSession session = sessionService.requireOwned(profileId, sessionId);

        // transcript는 변환기가 복호화해 평문으로 나온다 (Phase 3).
        List<TurnLog> turns = turnLogRepository.findBySessionIdOrderByTurnIndex(sessionId);
        Map<UUID, List<String>> tagsByTurn = historyRepository.tagsForTurns(
                turns.stream().map(TurnLog::getId).toList());

        return new SessionDetailResponse(
                session.getId(),
                session.getStartedAt(),
                session.getEndedAt(),
                session.getDurationSec(),
                session.getEndReason(),
                session.getThresholdMode(),
                session.getSummary(),
                turns.stream()
                        .map(t -> new SessionDetailResponse.Turn(
                                t.getId(), t.getTurnIndex(), t.getOccurredAt(), t.getRole(),
                                t.getTranscript(), t.getTextValence(), t.getVoiceValence(),
                                t.getGap(), t.isGapTriggered(),
                                tagsByTurn.getOrDefault(t.getId(), List.of())))
                        .toList());
    }
}
