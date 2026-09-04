package com.hackathonyaho.voicejournal.turn.service;

import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.SessionRef;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import com.hackathonyaho.voicejournal.common.ops.OpsErrorLogger;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.TurnStats;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import com.hackathonyaho.voicejournal.session.service.SessionService;
import com.hackathonyaho.voicejournal.turn.dto.request.TurnIngestRequest;
import com.hackathonyaho.voicejournal.turn.dto.response.LiveSignalResponse;
import com.hackathonyaho.voicejournal.turn.entity.TurnLog;
import com.hackathonyaho.voicejournal.turn.repository.CrisisEventRepository;
import com.hackathonyaho.voicejournal.turn.repository.TurnLogRepository;
import com.hackathonyaho.voicejournal.turn.repository.TurnTagRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** 턴 적재(F5-01)와 대화 중 신호(F4-04·F11-01). 필드의 단일 출처는 계약 §3-2·§2-13이다. */
@Slf4j
@Service
@RequiredArgsConstructor
public class TurnService {

    private static final String COLLISION = "TURN_INDEX_COLLISION";

    private final TurnLogRepository turnLogRepository;
    private final TurnTagRepository turnTagRepository;
    private final CrisisEventRepository crisisEventRepository;
    private final VoiceSessionRepository sessionRepository;
    private final ProfileRepository profileRepository;
    private final TurnStats turnStats;
    private final SessionService sessionService;
    private final OpsErrorLogger opsErrorLogger;

    // ── 적재 (F5-01) ────────────────────────────────────────────────

    @Transactional
    public void ingest(TurnIngestRequest request) {
        VoiceSession session = sessionRepository.findById(request.sessionId())
                // 4xx다 — AI서버는 재시도하지 않고 진행한다(계약 §3-2). 없는 세션에
                // 재시도를 시키면 3번 더 실패할 뿐이다.
                .orElseThrow(() -> new BusinessException(ErrorCode.SESSION_NOT_FOUND, "unknown session"));

        int turnIndex = resolveTurnIndex(request);
        if (turnIndex < 0) {
            return; // 재시도였다. 아무것도 하지 않고 202.
        }

        // saveAndFlush다 — 아래 태그 저장이 생 SQL이라 turn_log 행이 DB에 있어야 FK가 선다.
        TurnLog turn = turnLogRepository.saveAndFlush(TurnLog.of(
                request.sessionId(), turnIndex, request.role(), request.occurredAt(),
                request.transcript(), request.textValence(), request.voiceValence(),
                request.gap(), request.gapTriggeredOrFalse(), request.topProsody()));

        turnTagRepository.saveAll(turn.getId(), request.tags());

        if (request.crisisDetected()) {
            // 발화 내용도 turn_id도 넣지 않는다 (백엔드 절대 원칙 2번).
            crisisEventRepository.save(session.getProfileId(), session.getId(), request.crisisDetectedBy());
        }
    }

    /**
     * 중복 적재 처리 (3-1). <b>재시도면 {@code -1}</b>, 새 턴이면 저장할 인덱스를 준다.
     *
     * <p><b>이 판별이 없으면 방어가 유실 장치로 뒤집힌다.</b> 재시도 3회 때문에 같은 턴이
     * 실제로 두 번 오는데, {@code unique} 위반을 무조건 "이미 적재됨"으로 보면 이어하기
     * 후 인덱스가 리셋됐을 때 <b>새 발화가 전부 202를 받고 오류 없이 사라진다.</b>
     *
     * <p><b>{@code occurred_at}이 판별자인 이유</b> — 재시도는 같은 페이로드를 다시
     * 보내고, 충돌은 다른 발화다. 컬럼 하나 비교라 복호화도 해시도 필요 없다.
     * {@code created_at}(적재 시각)은 재시도마다 달라져 쓸 수 없다.
     *
     * <p><b>먼저 조회한다 — 위반을 잡아 되살리지 않는다.</b> 제약 위반은 트랜잭션을
     * 롤백 전용으로 만들어, 같은 트랜잭션에서 재번호 저장을 이어갈 수 없다. 인덱스가
     * 걸린 조회 한 번이 그 복잡함보다 싸다. 동시에 같은 턴이 두 번 들어오는 경합은
     * {@code unique}가 여전히 막고, 그때는 5xx → AI 재시도 → 이 경로에서 걸린다.
     */
    private int resolveTurnIndex(TurnIngestRequest request) {
        Optional<TurnLog> existing =
                turnLogRepository.findBySessionIdAndTurnIndex(request.sessionId(), request.turnIndex());
        if (existing.isEmpty()) {
            return request.turnIndex();
        }
        if (existing.get().getOccurredAt().equals(request.occurredAt())) {
            return -1;
        }

        int renumbered = turnStats.lastTurnIndex(request.sessionId()) + 1;
        // ⚠️ 이게 찍히면 정상 동작이 아니라 버그 신호다 — AI서버가 lastTurnIndex로
        // 채번을 시드하고 유휴 60초로 이어하기를 감지하므로 나오지 않아야 한다.
        // 한 건이라도 보이면 AI에 알린다. 발화 내용·sessionId는 남기지 않는다.
        opsErrorLogger.log("backend", COLLISION,
                "sessionRef=%s requested=%d stored=%d".formatted(
                        SessionRef.of(request.sessionId().toString()), request.turnIndex(), renumbered));
        return renumbered;
    }

    // ── 대화 중 신호 (계약 §2-13) ────────────────────────────────────

    @Transactional(readOnly = true)
    public LiveSignalResponse live(UUID profileId, UUID sessionId, Integer sinceTurnIndex) {
        sessionService.requireOwned(profileId, sessionId);

        boolean demoMode = profileRepository.findById(profileId).map(Profile::isDemoMode).orElse(false);
        // 생략이면 세션 시작부터다. 0이 아니라 -1인 이유는 turnIndex 0인 턴도 담기 위함이다.
        int since = sinceTurnIndex == null ? -1 : sinceTurnIndex;

        List<LiveSignalResponse.Turn> turns = demoMode
                ? turnLogRepository.findBySessionIdAndTurnIndexGreaterThanOrderByTurnIndex(sessionId, since)
                        .stream()
                        .map(t -> new LiveSignalResponse.Turn(t.getTurnIndex(), t.getTextValence(),
                                t.getVoiceValence(), t.getGap(), t.isGapTriggered()))
                        .toList()
                // 비데모는 빈 배열이고 null이 아니다 — §1-3의 null은 "측정하지 못했다"라서,
                // 마스킹에 쓰면 "측정 실패"와 "볼 권한 없음"이 같은 값이 된다.
                : List.of();

        return new LiveSignalResponse(
                sessionId,
                turnStats.lastTurnIndex(sessionId),
                // 데모 여부와 무관하게 항상 정상 값이다 — S07 위기 안내는 모든 사용자에게 떠야 한다.
                crisisEventRepository.existsForSession(sessionId),
                turns);
    }
}
