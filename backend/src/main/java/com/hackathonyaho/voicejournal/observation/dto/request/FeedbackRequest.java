package com.hackathonyaho.voicejournal.observation.dto.request;

import jakarta.validation.constraints.Pattern;

/** 계약 §2-7-1 (P1). 이유 입력·취소는 제공하지 않는다 — 붙는 순간 P1 범위를 벗어난다. */
public record FeedbackRequest(
        @Pattern(regexp = "agree|disagree", message = "feedback은 agree 또는 disagree입니다.")
        String feedback) {
}
