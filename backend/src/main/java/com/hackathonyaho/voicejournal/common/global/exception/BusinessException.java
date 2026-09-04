package com.hackathonyaho.voicejournal.common.global.exception;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import lombok.Getter;

@Getter
public class BusinessException extends RuntimeException {

    private final ErrorCode errorCode;

    public BusinessException(ErrorCode errorCode) {
        super(errorCode.name());
        this.errorCode = errorCode;
    }

    /**
     * 로그용 상세를 덧붙인다. <b>사용자 응답에는 ErrorCode의 문구가 나가고
     * 이 값은 나가지 않는다</b> — 발화 내용이 실릴 수 있는 자리라서다 (FR-092).
     */
    public BusinessException(ErrorCode errorCode, String detail) {
        super(detail);
        this.errorCode = errorCode;
    }
}
