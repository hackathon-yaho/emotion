package com.hackathonyaho.voicejournal.auth.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

/** 감정 데이터가 참조하는 유일한 주체. 개인정보가 없다. */
@Getter
@Entity
@Table(name = "profile")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Profile {

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    /**
     * F11-01 데모 모드. 심사 당일 {@code UPDATE} 한 줄로 켠다 — 재배포가 필요 없다.
     * account가 아니라 profile에 있는 이유는 조회 경로가 전부 profileId 기반이라
     * account 조인이 식별자 분리를 훼손하기 때문이다.
     */
    @Column(name = "demo_mode", nullable = false)
    private boolean demoMode;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /**
     * 생성자를 열지 않고 팩토리를 쓰는 이유 — JPA가 하이드레이션에 쓰는 no-arg
     * 생성자와 "새 프로필을 만든다"는 뜻이 겹치면, DB에서 읽을 때도 createdAt이
     * 한 번 찍히고 곧바로 덮인다. 뜻이 다른 둘을 이름으로 갈라둔다.
     */
    public static Profile create() {
        Profile profile = new Profile();
        profile.demoMode = false;
        profile.createdAt = Instant.now();
        return profile;
    }
}
