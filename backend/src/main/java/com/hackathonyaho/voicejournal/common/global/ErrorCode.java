package com.hackathonyaho.voicejournal.common.global;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 계약 §1-2의 오류 코드. 여기서 새 코드를 만들지 않는다 —
 * 앱이 code로 분기하므로 계약서를 먼저 고친다.
 *
 * <p>message는 사용자에게 그대로 보여도 되는 한국어 문장이다.
 * 앱이 code별 문구를 다시 만들지 않아도 되게 한다.
 */
@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "요청 형식이 올바르지 않습니다."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "로그인이 필요합니다."),
    TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "로그인이 만료되었습니다. 다시 로그인해 주세요."),
    KAKAO_VERIFY_FAILED(HttpStatus.UNAUTHORIZED, "카카오 로그인 확인에 실패했습니다. 다시 시도해 주세요."),
    INTERNAL_AUTH_FAILED(HttpStatus.UNAUTHORIZED, "내부 인증에 실패했습니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "접근할 수 없습니다."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "찾을 수 없습니다."),
    SESSION_NOT_FOUND(HttpStatus.NOT_FOUND, "대화를 찾을 수 없습니다."),
    OBSERVATION_NOT_FOUND(HttpStatus.NOT_FOUND, "발견을 찾을 수 없습니다."),
    QUEUE_TICKET_NOT_FOUND(HttpStatus.NOT_FOUND, "대기 순번이 만료되었습니다. 다시 시도해 주세요."),
    SESSION_NOT_RESUMABLE(HttpStatus.CONFLICT, "이어서 이야기할 수 있는 시간이 지났습니다."),
    HUME_TOKEN_ISSUE_FAILED(HttpStatus.SERVICE_UNAVAILABLE, "지금은 대화를 시작할 수 없습니다. 잠시 후 다시 시도해 주세요."),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "일시적인 문제가 생겼습니다. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
