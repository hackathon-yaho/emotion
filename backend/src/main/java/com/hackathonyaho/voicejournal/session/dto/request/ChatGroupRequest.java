package com.hackathonyaho.voicejournal.session.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 계약 §2-5-2. 앱이 EVI 소켓의 {@code chat_metadata}에서 받은 값을 그대로 올린다.
 *
 * <p><b>백엔드는 이 값을 해석하지 않는다</b> — Hume이 준 문자열을 보관했다가 이어하기 응답에
 * 그대로 돌려줄 뿐이다. 형식을 검사하면 Hume이 접두사를 바꾸는 날 우리가 먼저 깨진다.
 */
public record ChatGroupRequest(
        @NotBlank(message = "chatGroupId는 필수입니다.")
        @Size(max = 200, message = "chatGroupId가 너무 깁니다.")
        String chatGroupId) {
}
