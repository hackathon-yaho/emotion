package com.hackathonyaho.voicejournal.auth.controller;

import com.hackathonyaho.voicejournal.auth.dto.response.AuthResponse;
import com.hackathonyaho.voicejournal.auth.service.AuthService;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;

/**
 * 원티드 심사·투표용 로그인(계약 §2-1-1)과 대회 뒤 파기.
 *
 * <p><b>대회가 끝나고 파기까지 마치면 이 파일째 지운다</b> — 일정은
 * {@code docs/response/app/dev-login.md}.
 */
@RestController
public class DevLoginController {

    /** 서버 전체 분당 상한. IP별로 세지 않는 이유 — 프록시 뒤라 X-Forwarded-For를 믿어야 한다. */
    private static final int PER_MINUTE = 30;
    private static final Duration WINDOW = Duration.ofMinutes(1);

    private final AuthService authService;
    private final boolean enabled;

    private Instant windowStart = Instant.EPOCH;
    private int count;

    public DevLoginController(AuthService authService,
                              @Value("${app.dev-login.enabled}") boolean enabled) {
        this.authService = authService;
        this.enabled = enabled;
    }

    /** 계약 §2-1-1. 인증 불필요. 앱은 404를 「아직 준비되지 않았다」로 보여준다. */
    @PostMapping("/api/auth/dev")
    public ResponseEntity<AuthResponse> login() {
        if (!enabled) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "dev login disabled");
        }
        if (!acquire()) {
            throw new BusinessException(ErrorCode.TOO_MANY_REQUESTS, "dev login rate limit");
        }
        return ResponseEntity.ok(authService.loginAsGuest());
    }

    // ponytail: 인스턴스별 카운터라 인스턴스가 늘면 상한도 배로 는다. 심사 기간 한정이라 둔다.
    private synchronized boolean acquire() {
        Instant now = Instant.now();
        if (Duration.between(windowStart, now).compareTo(WINDOW) >= 0) {
            windowStart = now;
            count = 0;
        }
        return ++count <= PER_MINUTE;
    }

    /**
     * 대회 뒤 투표자 데이터 파기. {@code X-Internal-Secret}은 InternalAuthFilter가 본다.
     *
     * <p><b>로그인이 켜져 있으면 거절한다</b> — 지금 둘러보는 사람의 기록이 대화 도중에
     * 사라지고, 지운 직후에 새 프로필이 또 생긴다. 스위치를 먼저 끈다.
     */
    @PostMapping("/internal/dev-profiles/purge")
    public ResponseEntity<Map<String, Integer>> purge() {
        if (enabled) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "turn off DEV_LOGIN_ENABLED first");
        }
        return ResponseEntity.ok(Map.of("deleted", authService.purgeGuests()));
    }
}
