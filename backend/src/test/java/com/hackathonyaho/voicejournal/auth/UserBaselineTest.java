package com.hackathonyaho.voicejournal.auth;

import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * F3-04 임계값 모드 결정.
 *
 * <p>조건이 {@code session_count >= 5} 하나뿐이면, TC-06(분석 호출 실패)이 반복돼
 * 5세션 내내 갭이 NULL인 사용자가 <b>평균이 없는 상태로 personal로 전환</b>된다.
 * 화면은 멀쩡하고 임계값만 계산 불가가 되므로 조용히 틀린다.
 */
class UserBaselineTest {

    @Test
    @DisplayName("5회 미만이면 fixed")
    void underFiveSessions() {
        assertThat(baseline(4, "0.72").isPersonalThresholdReady()).isFalse();
    }

    @Test
    @DisplayName("5회 이상이고 평균이 있으면 personal")
    void readyForPersonal() {
        assertThat(baseline(5, "0.72").isPersonalThresholdReady()).isTrue();
    }

    @Test
    @DisplayName("5회를 넘겨도 평균이 NULL이면 fixed를 유지한다 — 가드가 없으면 여기서 뚫린다")
    void avgGapNullKeepsFixed() {
        assertThat(baseline(5, null).isPersonalThresholdReady()).isFalse();
        assertThat(baseline(50, null).isPersonalThresholdReady()).isFalse();
    }

    @Test
    @DisplayName("갓 만든 baseline은 fixed다 — 첫 사용자 데모가 작동해야 한다")
    void freshBaseline() {
        assertThat(new UserBaseline(UUID.randomUUID()).isPersonalThresholdReady()).isFalse();
    }

    private UserBaseline baseline(int sessionCount, String avgGap) {
        UserBaseline b = new UserBaseline(UUID.randomUUID());
        ReflectionTestUtils.setField(b, "sessionCount", sessionCount);
        ReflectionTestUtils.setField(b, "avgGap", avgGap == null ? null : new BigDecimal(avgGap));
        return b;
    }
}
