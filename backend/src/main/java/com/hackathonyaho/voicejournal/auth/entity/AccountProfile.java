package com.hackathonyaho.voicejournal.auth.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.UUID;

/**
 * 실명 계정 ↔ 감정 데이터를 잇는 <b>유일한</b> 연결자 (PRD §5.1).
 * 이 테이블을 조인하지 않으면 두 세계가 만나지 않는다.
 */
@Getter
@Entity
@Table(name = "account_profile")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AccountProfile {

    @Id
    @Column(name = "account_id", columnDefinition = "uuid")
    private UUID accountId;

    @Column(name = "profile_id", nullable = false, unique = true, columnDefinition = "uuid")
    private UUID profileId;

    public AccountProfile(UUID accountId, UUID profileId) {
        this.accountId = accountId;
        this.profileId = profileId;
    }
}
