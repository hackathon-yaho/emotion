package com.hackathonyaho.voicejournal.auth.controller;

import com.hackathonyaho.voicejournal.auth.dto.request.KakaoLoginRequest;
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
        return ResponseEntity.ok(authService.loginWithKakao(request.kakaoAccessToken()));
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
     * <p>카카오 연결 해제(unlink)는 <b>이 응답을 받은 뒤 앱이</b> SDK로 한다.
     * 서버에서 하려면 모든 사용자를 조작할 수 있는 Admin 키가 필요해서 두지 않는다.
     */
    @DeleteMapping("/account")
    public ResponseEntity<Void> withdraw() {
        ProfileContext.require();
        return ResponseEntity.noContent().build();
    }
}
