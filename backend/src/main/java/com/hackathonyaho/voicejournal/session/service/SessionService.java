package com.hackathonyaho.voicejournal.session.service;

import com.hackathonyaho.voicejournal.auth.dto.response.MeResponse;
import com.hackathonyaho.voicejournal.auth.entity.Profile;
import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.ProfileRepository;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import com.hackathonyaho.voicejournal.session.config.SessionPolicy;
import com.hackathonyaho.voicejournal.session.dto.response.InternalSessionResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionEndResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionResumeResponse;
import com.hackathonyaho.voicejournal.session.dto.response.SessionStartResponse;
import com.hackathonyaho.voicejournal.session.entity.VoiceSession;
import com.hackathonyaho.voicejournal.session.repository.TurnStats;
import com.hackathonyaho.voicejournal.session.repository.VoiceSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** F2 세션 수명주기. 응답 필드의 단일 출처는 계약 §2-4·§2-5·§2-5-1·§3-4다. */
@Slf4j
@Service
@RequiredArgsConstructor
public class SessionService {

    private static final String TIMEOUT = "timeout";

    private final VoiceSessionRepository sessionRepository;
    private final UserBaselineRepository baselineRepository;
    private final ProfileRepository profileRepository;
    private final TurnStats turnStats;
    private final HumeTokenService humeTokenService;
    private final SessionPolicy policy;

    // ── 시작 (F2-01) ────────────────────────────────────────────────

    @Transactional
    public SessionStartResponse start(UUID profileId) {
        // 토큰을 먼저 받는다 — 발급이 실패했는데 이전 세션만 닫혀 있으면
        // 사용자는 대화도 못 시작하고 이어하기 대상까지 잃는다.
        HumeTokenService.Token token = humeTokenService.issue();

        closeOpenSessions(profileId);

        UserBaseline baseline = baselineRepository.findById(profileId)
                .orElseGet(() -> baselineRepository.save(new UserBaseline(profileId)));
        String mode = baseline.isPersonalThresholdReady() ? VoiceSession.PERSONAL : VoiceSession.FIXED;

        VoiceSession session = sessionRepository.save(
                VoiceSession.start(profileId, mode, policy.getGapThreshold()));

        return new SessionStartResponse(
                session.getId(),
                token.accessToken(),
                token.expiresAt(),
                policy.getHumeConfigId(),
                mode,
                session.getGapThreshold(),
                policy.getSoftWrapSec(),
                policy.getHardCutSec(),
                policy.getLivePollIntervalSec(),
                demoMode(profileId));
    }

    /** 열린 세션을 남겨두면 동시 세션이 되고, 그 세션은 배치에서도 영영 빠진다. */
    private void closeOpenSessions(UUID profileId) {
        for (VoiceSession open : sessionRepository.findByProfileIdAndEndedAtIsNull(profileId)) {
            closeAsTimeout(open, lastActivityAt(open));
        }
    }

    // ── 종료 (F2-05) ────────────────────────────────────────────────

    /**
     * 이미 닫힌 세션에 다시 와도 <b>기록된 값을 그대로 돌려준다.</b> 앱이 종료 요청을
     * 재시도하는 것은 정상이고(네트워크가 끊긴 채 하드컷에 걸린 경우), 그때 404를
     * 주면 사용자는 방금 한 대화가 사라진 것으로 본다.
     */
    @Transactional
    public SessionEndResponse end(UUID profileId, UUID sessionId, String endReason) {
        VoiceSession session = mine(profileId, sessionId);

        if (session.isOpen()) {
            Instant now = Instant.now();
            session.end(endReason, now, (int) Duration.between(session.getStartedAt(), now).toSeconds());
            // F3-05(P1)가 아니라 종료의 기본 동작이다 — 잘려도 F3-04와 TC-07이 살아 있어야 한다.
            baselineRepository.findById(profileId).ifPresent(UserBaseline::countSession);
        }

        return new SessionEndResponse(
                session.getId(),
                session.getDurationSec() == null ? 0 : session.getDurationSec(),
                turnStats.turnCount(sessionId),
                session.getSummary(),
                turnStats.avgGap(sessionId));
    }

    // ── 이어하기 (F2-07, P1) ─────────────────────────────────────────

    @Transactional
    public SessionResumeResponse resume(UUID profileId, UUID sessionId) {
        VoiceSession session = mine(profileId, sessionId);
        if (!session.isOpen()) {
            // 종료·정리된 세션은 404다 (계약 §2-5-1).
            throw new BusinessException(ErrorCode.SESSION_NOT_FOUND, "session already ended");
        }

        Instant last = lastActivityAt(session);
        int remainingSec = policy.getHardCutSec() - usedSec(session, last);
        if (remainingSec <= 0 || Instant.now().isAfter(last.plus(policy.getResumeWindow()))) {
            throw new BusinessException(ErrorCode.SESSION_NOT_RESUMABLE, "resume window passed");
        }

        HumeTokenService.Token token = humeTokenService.issue();
        return new SessionResumeResponse(
                session.getId(),
                token.accessToken(),
                token.expiresAt(),
                policy.getHumeConfigId(),
                session.getHumeChatGroupId(),
                remainingSec,
                session.getThresholdMode(),
                // 이어하기는 같은 세션이므로 임계값이 바뀌지 않는다 — 스냅샷을 그대로 쓴다.
                session.getGapThreshold(),
                demoMode(profileId));
    }

    // ── AI서버용 세션 컨텍스트 (계약 §3-4) ────────────────────────────

    @Transactional(readOnly = true)
    public InternalSessionResponse context(UUID sessionId) {
        VoiceSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.SESSION_NOT_FOUND, "unknown session"));

        return new InternalSessionResponse(
                session.getId(),
                session.isOpen() ? "open" : "ended",
                session.getStartedAt(),
                usedSec(session, lastActivityAt(session)),
                turnStats.lastTurnIndex(sessionId),
                session.getThresholdMode(),
                session.getGapThreshold(),
                policy.getSoftWrapSec(),
                policy.getHardCutSec(),
                demoMode(session.getProfileId()),
                // Phase 4에서 채운다. 그전까지 빈 배열인 것이 정상이다.
                List.of());
    }

    // ── GET /api/me의 openSession (F2-07 준비) ───────────────────────

    @Transactional(readOnly = true)
    public MeResponse.OpenSession openSession(UUID profileId) {
        return sessionRepository.findFirstByProfileIdAndEndedAtIsNullOrderByStartedAtDesc(profileId)
                .map(session -> {
                    Instant last = lastActivityAt(session);
                    int used = usedSec(session, last);
                    return new MeResponse.OpenSession(
                            session.getId(),
                            session.getStartedAt(),
                            used,
                            Math.max(0, policy.getHardCutSec() - used),
                            last.plus(policy.getResumeWindow()));
                })
                .orElse(null);
    }

    // ── F2-06 미종료 세션 정리 ────────────────────────────────────────

    /**
     * 이게 없으면 앱 강제 종료·배터리 방전으로 끊긴 세션이 열린 채 남고,
     * {@code pattern_processed_at}이 영영 NULL이라 <b>그 대화가 관찰 집계에서 통째로 빠진다.</b>
     */
    @Transactional
    public int closeAbandonedSessions() {
        Instant now = Instant.now();
        int closed = 0;
        for (VoiceSession session : sessionRepository.findByEndedAtIsNull()) {
            Instant last = lastActivityAt(session);
            if (now.isAfter(last.plus(policy.getResumeWindow()))) {
                closeAsTimeout(session, last);
                closed++;
            }
        }
        return closed;
    }

    /** 요약을 만들지 않는다 — 아무도 보고 있지 않은 세션이고, 건당 3초가 스케줄러를 막는다. */
    private void closeAsTimeout(VoiceSession session, Instant lastActivityAt) {
        int used = usedSec(session, lastActivityAt);
        session.end(TIMEOUT, session.getStartedAt().plusSeconds(used), used);
        baselineRepository.findById(session.getProfileId()).ifPresent(UserBaseline::countSession);
    }

    // ── 공통 ────────────────────────────────────────────────────────

    /**
     * <b>실제로 말한 시간이다 — 시작 후 흐른 시간이 아니다.</b> 앱이 죽으면 종료 신호가
     * 오지 않으므로 벽시계로 재면, 5분 뒤 이어하기를 시도한 사용자에게 잔여 시간이
     * 0이 되어 TC-22가 깨진다.
     */
    private int usedSec(VoiceSession session, Instant lastActivityAt) {
        long used = Duration.between(session.getStartedAt(), lastActivityAt).toSeconds();
        return (int) Math.max(0, Math.min(used, policy.getHardCutSec()));
    }

    /**
     * <b>호출자가 한 번 읽어 돌려쓴다.</b> 이 값 하나로 {@code usedSec}·잔여 시간·이어하기
     * 창이 전부 결정되는데, 필요할 때마다 다시 읽으면 같은 요청 안에서 DB 왕복이 세 번
     * 나고 <b>그 사이에 턴이 들어오면 세 값이 서로 어긋난다.</b>
     *
     * <p>이어하기 창은 이 시각 + 30분이고, 그게 곧 스케줄러의 정리 시점이다 (계약 §2-2).
     */
    private Instant lastActivityAt(VoiceSession session) {
        return turnStats.lastActivityAt(session.getId(), session.getStartedAt());
    }

    private VoiceSession mine(UUID profileId, UUID sessionId) {
        VoiceSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.SESSION_NOT_FOUND, "unknown session"));
        if (!session.getProfileId().equals(profileId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "session belongs to another profile");
        }
        return session;
    }

    private boolean demoMode(UUID profileId) {
        return profileRepository.findById(profileId).map(Profile::isDemoMode).orElse(false);
    }
}
