package com.hackathonyaho.voicejournal.auth.security;

import java.util.UUID;

/**
 * 인증된 요청의 profileId를 담는다.
 *
 * <p><b>kakaoId는 여기 들어오지 않는다.</b> 컨트롤러·서비스 어디에도
 * 카카오 식별자가 흘러다니지 않게 한다 — 식별자 분리(PRD §5.1)는
 * 테이블만 나눈다고 지켜지지 않고, 코드가 조인하면 무너진다.
 */
public final class ProfileContext {

    private static final ThreadLocal<UUID> CURRENT = new ThreadLocal<>();

    private ProfileContext() {
    }

    public static void set(UUID profileId) {
        CURRENT.set(profileId);
    }

    public static UUID require() {
        UUID id = CURRENT.get();
        if (id == null) {
            throw new IllegalStateException("no authenticated profile in context");
        }
        return id;
    }

    public static void clear() {
        CURRENT.remove();
    }
}
