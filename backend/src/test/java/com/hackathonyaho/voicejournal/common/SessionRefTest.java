package com.hackathonyaho.voicejournal.common;

import com.hackathonyaho.voicejournal.common.global.SessionRef;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 절대 원칙 6번(sessionId 로깅 금지)을 지키면서 상관은 되게 하는 장치다.
 * 이 성질이 깨지면 규칙을 어기거나 추적이 불가능해진다.
 */
class SessionRefTest {

    private static final String SESSION_ID = "550e8400-e29b-41d4-a716-446655440000";

    @Test
    @DisplayName("같은 세션은 같은 값으로, 다른 세션은 다른 값으로 묶인다")
    void deterministic() {
        assertThat(SessionRef.of(SESSION_ID)).isEqualTo(SessionRef.of(SESSION_ID));
        assertThat(SessionRef.of(SESSION_ID))
                .isNotEqualTo(SessionRef.of("550e8400-e29b-41d4-a716-446655440001"));
    }

    @Test
    @DisplayName("원본 sessionId가 값 안에 드러나지 않는다 — 드러나면 원칙 6번 위반이다")
    void doesNotLeakOriginal() {
        String ref = SessionRef.of(SESSION_ID);

        assertThat(ref).hasSize(8);
        assertThat(SESSION_ID).doesNotContain(ref);
        // UUID 조각이 그대로 실리지 않는지
        assertThat(ref).isNotEqualTo(SESSION_ID.substring(0, 8));
    }

    @Test
    @DisplayName("세션 컨텍스트가 없어도 터지지 않는다")
    void nullSafe() {
        assertThat(SessionRef.of(null)).isEqualTo("-");
        assertThat(SessionRef.of("")).isEqualTo("-");
    }
}
