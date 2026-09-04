package com.hackathonyaho.voicejournal.common.global;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hackathonyaho.voicejournal.common.global.dto.ErrorResponse;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;

import java.io.IOException;
import java.util.UUID;

/**
 * 필터는 {@code GlobalExceptionHandler}를 타지 못한다. 그렇다고 필터마다 오류 봉투를
 * 손으로 만들면 계약 §1-2의 모양이 조용히 갈라진다 — 앱은 {@code error.code}로 분기한다.
 */
public final class ErrorWriter {

    private ErrorWriter() {
    }

    public static void write(HttpServletResponse response, ObjectMapper mapper, ErrorCode code)
            throws IOException {
        String traceId = UUID.randomUUID().toString().substring(0, 8);
        response.setStatus(code.getStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        mapper.writeValue(response.getWriter(), ErrorResponse.of(code, traceId));
    }
}
