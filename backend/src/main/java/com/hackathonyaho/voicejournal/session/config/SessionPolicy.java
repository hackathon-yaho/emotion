package com.hackathonyaho.voicejournal.session.config;

import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Duration;

/**
 * 세션 정책값. <b>앱에 상수로 박지 않고 서버가 내려준다</b>(계약 §2-4) — 정책이 바뀔 때
 * 앱 재배포가 필요하면 도그푸딩 중에 못 바꾼다.
 */
@Getter
@Component
public class SessionPolicy {

    private final int softWrapSec;
    private final int hardCutSec;
    private final int livePollIntervalSec;
    private final BigDecimal gapThreshold;
    private final Duration resumeWindow;

    /**
     * <b>{@code humeConfigId}는 null이 될 수 없다</b>(계약 §2-4). 기본값을 주지 않으므로
     * 값이 없으면 <b>기동에 실패한다</b> — 런타임 503으로 만들면 서버는 멀쩡히 떠 있는데
     * 모든 세션 시작이 실패하고, 원인 추적이 "Hume이 왜 이러지"에서 시작해 한참 돌아
     * 설정 파일에 도착한다.
     */
    private final String humeConfigId;

    public SessionPolicy(
            @Value("${app.session.soft-wrap-sec}") int softWrapSec,
            @Value("${app.session.hard-cut-sec}") int hardCutSec,
            @Value("${app.session.live-poll-interval-sec}") int livePollIntervalSec,
            @Value("${app.session.gap-threshold}") BigDecimal gapThreshold,
            @Value("${app.session.resume-window-min}") int resumeWindowMin,
            @Value("${app.hume.config-id}") String humeConfigId) {
        this.softWrapSec = softWrapSec;
        this.hardCutSec = hardCutSec;
        this.livePollIntervalSec = livePollIntervalSec;
        this.gapThreshold = gapThreshold;
        this.resumeWindow = Duration.ofMinutes(resumeWindowMin);
        // 빈 문자열도 미설정이다 — 대시보드에서 변수를 만들어놓고 값을 안 넣는 쪽이
        // 변수를 아예 빠뜨리는 것보다 흔하다.
        if (humeConfigId == null || humeConfigId.isBlank()) {
            throw new IllegalStateException("HUME_CONFIG_ID is required (계약 §2-4: humeConfigId는 null 불가)");
        }
        this.humeConfigId = humeConfigId;
    }
}
