package com.hackathonyaho.voicejournal.auth.dto.response;

import java.time.Instant;
import java.util.UUID;

/**
 * 계약 §2-1.
 *
 * <p>{@code expiresAt}은 JWT 만료와 같은 값이다 — 앱이 토큰을 파싱하지 않아도 되게 한다.
 * {@code isNewUser}는 앱이 온보딩 고지(F1-05)를 띄울지 판단하는 데만 쓴다.
 */
public record AuthResponse(String jwt, Instant expiresAt, UUID profileId, boolean isNewUser) {
}
