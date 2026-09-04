package com.hackathonyaho.voicejournal.auth.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

/**
 * 카카오 식별자를 담는 유일한 테이블 (PRD §5.1 식별자 분리).
 *
 * <p><b>감정 데이터는 이 엔티티를 참조하지 않는다.</b> Profile과의 연결은
 * AccountProfile 한 곳에만 있고, 그 조인을 하지 않으면 어떤 감정 데이터도
 * 실명 계정에 닿지 않는다. 그래서 여기에 Profile 참조를 두지 않는다 —
 * 연관을 만들어두면 코드가 언젠가 그 길로 간다.
 */
@Getter
@Entity
@Table(name = "account")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Account {

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    /** 카카오 회원번호 — {@code GET /v2/user/me}의 {@code id}. 앱마다 다른 값이다. */
    @Column(name = "kakao_id", nullable = false, unique = true)
    private String kakaoId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public Account(String kakaoId) {
        this.kakaoId = kakaoId;
        this.createdAt = Instant.now();
    }
}
