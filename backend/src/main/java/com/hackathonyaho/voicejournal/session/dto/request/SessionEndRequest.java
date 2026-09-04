package com.hackathonyaho.voicejournal.session.dto.request;

import jakarta.validation.constraints.Pattern;

/**
 * 계약 §2-5. <b>앱은 {@code timeout}·{@code resumed}를 보내지 않는다</b> — 서버 내부
 * 기록용이라 여기서 거른다. 받아주면 사용자가 끊은 대화가 스케줄러 정리로 집계된다.
 */
public record SessionEndRequest(
        @Pattern(regexp = "user_end|soft_wrap|hard_cut", message = "endReason이 올바르지 않습니다.")
        String endReason) {

    public String endReasonOrDefault() {
        return endReason == null || endReason.isBlank() ? "user_end" : endReason;
    }
}
