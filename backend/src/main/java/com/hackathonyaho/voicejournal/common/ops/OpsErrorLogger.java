package com.hackathonyaho.voicejournal.common.ops;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 운영 오류 적재 (F11-03). <b>발화 내용·{@code sessionId}를 넣지 않는다</b>(FR-092) —
 * 세션 상관은 {@code sessionRef}(SHA-256 앞 8자)로만 한다.
 *
 * <p>탈퇴 삭제 대상이 아니다. 사용자 데이터를 담지 않기 때문이다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OpsErrorLogger {

    private final JdbcTemplate jdbc;

    /**
     * <b>새 트랜잭션으로 쓴다.</b> 오류를 남기는 쪽은 대개 롤백되는 경로인데, 같은
     * 트랜잭션에 실으면 <b>기록도 함께 사라져 "왜 실패했는지"가 남지 않는다.</b>
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void log(String service, String code, String message) {
        try {
            jdbc.update("insert into ops_error_log (service, code, message) values (?, ?, ?)",
                    service, code, message);
        } catch (Exception e) {
            // 기록에 실패했다고 본래 처리를 막지 않는다.
            log.warn("ops_error_log write failed: {} ({})", code, e.getClass().getSimpleName());
        }
    }
}
