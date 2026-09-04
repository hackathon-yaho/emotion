package com.hackathonyaho.voicejournal.auth.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * F3-04 임계값 모드의 입력. Phase 3에서 갱신 로직이 붙는다.
 *
 * <p>Phase 1에서 만드는 이유는 {@code GET /api/me}의 {@code sessionCount}가
 * 이 값을 읽기 때문이다.
 */
@Getter
@Entity
@Table(name = "user_baseline")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserBaseline {

    @Id
    @Column(name = "profile_id", columnDefinition = "uuid")
    private UUID profileId;

    /** 증가는 세션 종료의 기본 동작이다 — F3-05(P1)가 잘려도 이건 남는다. */
    @Column(name = "session_count", nullable = false)
    private int sessionCount;

    @Column(name = "avg_gap")
    private BigDecimal avgGap;

    @Column(name = "stddev_gap")
    private BigDecimal stddevGap;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public UserBaseline(UUID profileId) {
        this.profileId = profileId;
        this.sessionCount = 0;
        this.updatedAt = Instant.now();
    }

    /**
     * F3-04 — {@code session_count >= 5} <b>AND</b> {@code avg_gap IS NOT NULL}.
     *
     * <p>가드가 없으면 5세션 내내 분석이 실패한 사용자(TC-06 반복)가
     * <b>평균이 없는 상태로 personal로 전환</b>된다.
     */
    public boolean isPersonalThresholdReady() {
        return sessionCount >= 5 && avgGap != null;
    }

    /**
     * 세션 종료마다 1 증가한다. <b>F3-05(P1 통계 갱신)가 아니라 종료의 기본 동작이다</b> —
     * 스코프 컷으로 F3-05를 잘라도 P0인 F3-04와 TC-07이 살아 있어야 한다.
     */
    /** F3-05. 전부 NULL일 수 있다 — 분석이 한 번도 성공하지 않은 사용자다(TC-06 반복). */
    public void updateGapStats(BigDecimal avgGap, BigDecimal stddevGap) {
        this.avgGap = avgGap;
        this.stddevGap = stddevGap;
        this.updatedAt = Instant.now();
    }

    public void countSession() {
        this.sessionCount++;
        this.updatedAt = Instant.now();
    }
}
