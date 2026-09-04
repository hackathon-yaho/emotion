package com.hackathonyaho.voicejournal.observation.dto.response;

/** 계약 §2-7-1. <b>disagree가 관찰을 삭제하지 않는다</b> — 표시만 남긴다. */
public record FeedbackResponse(String observationId, String feedback) {
}
