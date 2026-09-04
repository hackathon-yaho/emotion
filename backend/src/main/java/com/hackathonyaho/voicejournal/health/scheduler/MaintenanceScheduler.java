package com.hackathonyaho.voicejournal.health.scheduler;

import com.hackathonyaho.voicejournal.observation.service.ObservationBatchService;
import com.hackathonyaho.voicejournal.session.service.SessionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * F2-06 미종료 세션 정리(Phase 2)와 F7-01 배치 스캔(Phase 4)이 <b>같은 스케줄러</b>에
 * 올라탄다 — 추가 인프라 0.
 *
 * <p><b>주기 5분.</b> F2-06이 "마지막 발화 후 30분 경과"를 판정하므로 실제 종료
 * 시각의 오차가 최대 5분이고, {@code resumableUntil}이 같은 시각이라 이어하기 창도
 * 그만큼만 밀린다. 1분은 빈 스캔이 60배로 늘고(관찰은 3회·1.5배 조건이라 어차피
 * 매번 생기지 않는다), 10분은 이어하기 창이 40분까지 밀린다.
 *
 * <p><b>fixedRate가 아니라 fixedDelay다</b> — 배치가 오래 걸릴 때 겹쳐 도는 것을 막는다.
 * 인스턴스는 Render Free라 1개뿐이므로 분산 락은 필요 없다.
 *
 * <p>Render가 슬립하면 이 스케줄러도 멈춘다. cron이 10분마다 {@code /api/health}를
 * 쳐서 깨워두지만, 슬립 구간에 밀린 세션은 깨어난 뒤 다음 주기에 주워간다 —
 * {@code pattern_processed_at} 컬럼 방식이라 유실이 없다(F7-01).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MaintenanceScheduler {

    private final SessionService sessionService;
    private final ObservationBatchService observationBatchService;

    @Scheduled(fixedDelayString = "${app.scheduler.fixed-delay-ms}")
    public void tick() {
        // 각 작업은 예외를 스스로 삼킨다 — 하나가 실패해도 다음 작업과 다음 주기가
        // 영향을 받지 않아야 한다 (F7-01 수용 기준: 배치 실패가 대화·조회에 영향 없음).
        closeAbandonedSessions();
        runPatternBatch();
    }

    /** F7-01. 배치 실패가 대화·조회에 영향을 주지 않아야 한다 — 여기서 삼킨다. */
    private void runPatternBatch() {
        try {
            int created = observationBatchService.runPending();
            if (created > 0) {
                log.info("created {} observation(s)", created);
            }
        } catch (Exception e) {
            log.warn("pattern batch failed ({})", e.getClass().getSimpleName());
        }
    }

    /** F2-06. 세션 ID는 로그에 남기지 않는다 — 건수만 남긴다(FR-092, 계약 §1-1). */
    private void closeAbandonedSessions() {
        try {
            int closed = sessionService.closeAbandonedSessions();
            if (closed > 0) {
                log.info("closed {} abandoned session(s)", closed);
            }
        } catch (Exception e) {
            log.warn("abandoned session cleanup failed ({})", e.getClass().getSimpleName());
        }
    }
}
