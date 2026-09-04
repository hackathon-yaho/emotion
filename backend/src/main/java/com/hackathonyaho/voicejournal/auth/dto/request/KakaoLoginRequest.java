package com.hackathonyaho.voicejournal.auth.dto.request;

import jakarta.validation.constraints.NotBlank;

/**
 * 계약 §2-1 (v1.6). <b>액세스 토큰이 아니라 인가 코드</b>를 받는다 — 웹에서는 앱이
 * 토큰을 손에 쥘 수 없다.
 *
 * <p>{@code redirectUri}를 앱이 같이 보내는 이유는 카카오 토큰 교환이 인가 때 쓴 값과의
 * 일치를 요구하는데 로컬과 배포가 다르기 때문이다. <b>서버가 등록 목록과 대조한다.</b>
 */
public record KakaoLoginRequest(
        @NotBlank(message = "kakaoAuthCode는 필수입니다.")
        String kakaoAuthCode,

        @NotBlank(message = "redirectUri는 필수입니다.")
        String redirectUri) {
}
