package com.hackathonyaho.voicejournal.session.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** 대화 세션 (F2). 스키마는 {@code db/migration.sql}이 단일 출처다. */
@Getter
@Entity
@Table(name = "voice_session")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class VoiceSession {

    public static final String FIXED = "fixed";
    public static final String PERSONAL = "personal";

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "profile_id", nullable = false, columnDefinition = "uuid")
    private UUID profileId;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    @Column(name = "duration_sec")
    private Integer durationSec;

    @Column(name = "threshold_mode", nullable = false)
    private String thresholdMode;

    /**
     * <b>그 세션에 실제로 적용된 임계값 스냅샷.</b> 현재 설정값을 다시 읽어 소급 판정하면
     * 임계값이 확정되는 순간(PRD §14-5) 과거 트렌드의 음영이 통째로 바뀐다 — F9-02.
     */
    @Column(name = "gap_threshold", nullable = false)
    private BigDecimal gapThreshold;

    @Column(name = "end_reason")
    private String endReason;

    @Column(name = "summary")
    private String summary;

    @Column(name = "hume_chat_group_id")
    private String humeChatGroupId;

    /** NULL이면 패턴 배치 미처리. 별도 큐를 두지 않는 근거다 (F7-01). */
    @Column(name = "pattern_processed_at")
    private Instant patternProcessedAt;

    public static VoiceSession start(UUID profileId, String thresholdMode, BigDecimal gapThreshold) {
        VoiceSession session = new VoiceSession();
        session.profileId = profileId;
        session.startedAt = Instant.now();
        session.thresholdMode = thresholdMode;
        session.gapThreshold = gapThreshold;
        return session;
    }

    public boolean isOpen() {
        return endedAt == null;
    }

    /** 종료는 한 번만 성립한다 — 스케줄러와 사용자가 같은 세션을 동시에 닫을 수 있다. */
    public void end(String reason, Instant at, int durationSec) {
        if (endedAt != null) {
            return;
        }
        this.endReason = reason;
        this.endedAt = at;
        this.durationSec = durationSec;
    }

    /** 성공했을 때만 찍는다 — NULL로 남으면 다음 주기에 자동 재시도된다 (F7-01). */
    public void markPatternProcessed() {
        this.patternProcessedAt = Instant.now();
    }

    public void attachSummary(String summary) {
        this.summary = summary;
    }

    /**
     * 마지막으로 받은 값이 이긴다. 같은 값이 여러 번 오면 아무 일도 안 일어난 것과 같고,
     * 다른 값이 오면 <b>새 그룹이 생겼다는 뜻</b>이라 이전 그룹에는 이어붙을 맥락이 없다.
     */
    public void attachChatGroup(String chatGroupId) {
        this.humeChatGroupId = chatGroupId;
    }
}
