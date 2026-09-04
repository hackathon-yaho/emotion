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

    /**
     * 깨진 JSON·읽을 수 없는 본문. <b>500이 아니라 400이어야 한다</b> — 계약 §3-2에서
     * AI서버는 5xx를 <b>3회 재시도</b>하는데, 본문이 깨진 요청은 몇 번을 보내도 같은
     * 결과다. 재시도가 세 번 더 실패하고 로그만 세 배로 쌓이며, 원인이 "본문이 깨졌다"가
     * 아니라 "백엔드가 죽었다"로 보인다.
     *
     * <p><b>예외 메시지를 로그에 넣지 않는다.</b> 파서 오류에는 본문 조각이 실릴 수 있고
     * 그 조각이 곧 발화다(FR-092). Jackson이 기본으로 가리지만 설정 하나에 달린 방어를
     * 믿지 않는다 — 종류만 남긴다.
     */
    @org.springframework.web.bind.annotation.ExceptionHandler(
            org.springframework.http.converter.HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleUnreadableBody(
            org.springframework.http.converter.HttpMessageNotReadableException e) {
        String traceId = newTraceId();
        log.warn("[{}] VALIDATION_ERROR - unreadable body ({})", traceId,
                e.getMostSpecificCause().getClass().getSimpleName());
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
