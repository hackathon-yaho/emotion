package com.hackathonyaho.voicejournal.common.global;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 로그 상관 수단. {@code SHA-256(sessionId)[:8]}.
 *
 * <p>절대 원칙 6번이 {@code sessionId} 로깅을 금지한다 — CLM 인증 수단이라
 * 비밀과 동급이다. 그렇다고 아무것도 안 남기면 {@code /internal/turns} 실패를
 * 추적할 수단이 0이 된다. 해시는 원본을 복원할 수 없어 인증에 쓸 수 없으므로
 * 규칙을 깨지 않으면서 같은 세션의 오류끼리 묶인다.
 *
 * <p>로그 → DB 방향은 열려 있고(같은 해시를 만들어 대조), 로그만으로는 아무것도 못 한다.
 */
public final class SessionRef {

    private SessionRef() {
    }

    public static String of(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return "-";
        }
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(sessionId.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest).substring(0, 8);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
