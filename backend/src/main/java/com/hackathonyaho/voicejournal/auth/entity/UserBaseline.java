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
}
