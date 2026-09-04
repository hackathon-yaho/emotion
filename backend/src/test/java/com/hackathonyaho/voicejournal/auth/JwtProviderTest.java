package com.hackathonyaho.voicejournal.auth;

import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtProviderTest {

    private static final String SECRET = "test-only-secret-not-used-in-deployment-0000000";

    private final JwtProvider provider = new JwtProvider(SECRET, 7);

    @Test
    @DisplayName("발급한 토큰에서 같은 profileId가 나온다")
    void roundTrip() {
        UUID profileId = UUID.randomUUID();

        JwtProvider.Issued issued = provider.issue(profileId);

        assertThat(provider.parseProfileId(issued.token())).isEqualTo(profileId);
        assertThat(issued.expiresAt()).isAfter(java.time.Instant.now());
    }

    @Test
    @DisplayName("다른 키로 서명된 토큰은 거부한다")
    void rejectsForeignSignature() {
        String foreign = new JwtProvider("another-secret-of-sufficient-length-for-hmac", 7)
                .issue(UUID.randomUUID()).token();

        assertThatThrownBy(() -> provider.parseProfileId(foreign))
                .isInstanceOf(JwtException.class);
    }

    @Test
    @DisplayName("만료 토큰은 ExpiredJwtException으로 구분된다 — 앱이 TOKEN_EXPIRED로 재로그인한다")
    void expiredIsDistinguishable() {
        String expired = new JwtProvider(SECRET, -1).issue(UUID.randomUUID()).token();

        assertThatThrownBy(() -> provider.parseProfileId(expired))
                .isInstanceOf(ExpiredJwtException.class);
    }
}
