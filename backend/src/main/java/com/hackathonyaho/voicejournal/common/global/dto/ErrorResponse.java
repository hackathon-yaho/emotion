package com.hackathonyaho.voicejournal.common.global.dto;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;

/** 계약 §1-2 — 모든 오류가 같은 모양이다. */
public record ErrorResponse(Body error) {

    public record Body(String code, String message, String traceId) {
    }

    public static ErrorResponse of(ErrorCode code, String traceId) {
        return new ErrorResponse(new Body(code.name(), code.getMessage(), traceId));
    }

    public static ErrorResponse of(ErrorCode code, String message, String traceId) {
        return new ErrorResponse(new Body(code.name(), message, traceId));
    }
}
