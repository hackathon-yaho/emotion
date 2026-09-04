package com.hackathonyaho.voicejournal.auth.controller;

import com.hackathonyaho.voicejournal.auth.dto.request.KakaoLoginRequest;
import com.hackathonyaho.voicejournal.auth.dto.request.WithdrawRequest;
import com.hackathonyaho.voicejournal.auth.dto.response.AuthResponse;
import com.hackathonyaho.voicejournal.auth.dto.response.MeResponse;
import com.hackathonyaho.voicejournal.auth.security.ProfileContext;
import com.hackathonyaho.voicejournal.auth.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** 응답 스키마는 계약 §2-1·§2-2·§2-3이 단일 출처다. */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /** 계약 §2-1. 인증 불필요. */
    @PostMapping("/auth/kakao")
    public ResponseEntity<AuthResponse> loginWithKakao(@Valid @RequestBody KakaoLoginRequest request) {
        return ResponseEntity.ok(authService.loginWithKakao(request.kakaoAuthCode(), request.redirectUri()));
    }

    /** 계약 §2-2. */
    @GetMapping("/me")
    public ResponseEntity<MeResponse> me() {
        return ResponseEntity.ok(authService.me(ProfileContext.require()));
    }

    /**
     * 계약 §2-3 탈퇴 (F1-04 · F10-03).
     *
     * <p><b>Phase 1에서는 경로와 인증만 걸어둔다.</b> 실제 10테이블 삭제는 Phase 6에서
     * 채운다 — 삭제 순서를 검증하려면 그 테이블들에 데이터가 있어야 한다.
     *
     * <p>카카오 연결 해제는 <b>서버가</b> 한다(v1.6). 인가 코드 방식으로 바뀌면서 앱에
     * 카카오 자격증명이 남지 않기 때문이다. 어드민 키는 여전히 쓰지 않는다 — 본문으로
     * 온 인가 코드를 사용자 토큰으로 바꿔 자기 계정만 끊는다.
     *
     * <p><b>본문은 선택이다.</b> 없으면 데이터만 지우고 똑같이 204다.
     */
    @DeleteMapping("/account")
    public ResponseEntity<Void> withdraw(@RequestBody(required = false) WithdrawRequest request) {
        ProfileContext.require();
        return ResponseEntity.noContent().build();
    }
}
