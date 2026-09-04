package com.hackathonyaho.voicejournal.auth.dto.request;

import jakarta.validation.constraints.NotBlank;

/** 계약 §2-1. */
public record KakaoLoginRequest(@NotBlank String kakaoAccessToken) {
}
