package com.hackathonyaho.voicejournal.common.global.handler;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.dto.ErrorResponse;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.UUID;

/** 응답 형태를 계약 §1-2 하나로 통일한다. */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @org.springframework.web.bind.annotation.ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusiness(BusinessException e) {
        ErrorCode code = e.getErrorCode();
        String traceId = newTraceId();
        // 예외 메시지에는 상세가 실릴 수 있어 로그에만 남긴다.
        log.warn("[{}] {} - {}", traceId, code.name(), e.getMessage());
        return ResponseEntity.status(code.getStatus()).body(ErrorResponse.of(code, traceId));
    }

    @org.springframework.web.bind.annotation.ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException e) {
        String traceId = newTraceId();
        // 필드명만 남긴다. 값에는 발화가 실릴 수 있다 (FR-092).
        String fields = e.getBindingResult().getFieldErrors().stream()
                .map(org.springframework.validation.FieldError::getField)
                .distinct()
                .reduce((a, b) -> a + ", " + b)
                .orElse("-");
        log.warn("[{}] VALIDATION_ERROR - fields: {}", traceId, fields);
        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.getStatus())
                .body(ErrorResponse.of(ErrorCode.VALIDATION_ERROR, traceId));
    }

    @org.springframework.web.bind.annotation.ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception e) {
        String traceId = newTraceId();
        log.error("[{}] INTERNAL_ERROR", traceId, e);
        return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.getStatus())
                .body(ErrorResponse.of(ErrorCode.INTERNAL_ERROR, traceId));
    }

    /**
     * 세션 컨텍스트가 있는 요청은 {@code SessionRef}를 traceId로 쓴다.
     * 없는 요청(로그인·헬스체크 등)은 임의 8자로 충분하다.
     */
    private String newTraceId() {
        String fromMdc = org.slf4j.MDC.get("sessionRef");
        return fromMdc != null ? fromMdc : UUID.randomUUID().toString().substring(0, 8);
    }
}
