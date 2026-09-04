package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.auth.security.JwtProvider;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Phase 1 통합 — compose Postgres의 테스트 전용 DB에 붙는다 (phase-1 1-9).
 * 스키마는 {@code db/migration.sql}을 그대로 적용하므로 <b>배포와 같은 파일로 검증</b>된다.
 *
 * <p>Docker가 떠 있어야 한다: {@code docker compose up -d}
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ApiIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JwtProvider jwtProvider;

    /** 만료 토큰을 만들려면 <b>애플리케이션과 같은 키</b>로 서명해야 한다 — 다르면 위조로 걸린다. */
    @org.springframework.beans.factory.annotation.Value("${app.jwt.secret}")
    String jwtSecret;

    @Test
    @DisplayName("헬스체크가 DB에 실제로 닿는다 — 단순 ok 반환이 아니다")
    void healthChecksDatabase() throws Exception {
        mvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"))
                .andExpect(jsonPath("$.db").value("ok"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    @DisplayName("JWT 없이 감정 데이터 API를 호출하면 401이다 (F1-02 수용 기준)")
    void requiresJwt() throws Exception {
        mvc.perform(get("/api/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.traceId").exists());
    }

    @Test
    @DisplayName("만료된 JWT는 UNAUTHORIZED가 아니라 TOKEN_EXPIRED다 — 앱이 재로그인으로 분기한다")
    void expiredTokenHasOwnCode() throws Exception {
        String expired = new JwtProvider(jwtSecret, -1).issue(UUID.randomUUID()).token();

        mvc.perform(get("/api/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_EXPIRED"));
    }

    /**
     * <b>이 테스트가 Phase 1에서 가장 값이 나간다.</b> JWT 필터를 "인증 제외 경로"로만
     * 관리하면 프리플라이트가 401로 막히는데, 그 실패는 앱에서 그냥 네트워크 오류로
     * 보이고 서버에는 401만 남아 원인이 CORS라는 걸 알아채기 어렵다.
     */
    @Test
    @DisplayName("CORS 프리플라이트는 Authorization 없이 통과한다")
    void preflightPassesWithoutAuth() throws Exception {
        mvc.perform(options("/api/me")
                        .header(HttpHeaders.ORIGIN, "https://hackathon-yaho.github.io")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "GET")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "authorization"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "https://hackathon-yaho.github.io"));
    }

    @Test
    @DisplayName("로컬 개발 오리진은 포트를 고정하지 않아도 통과한다 (allowedOriginPatterns)")
    void preflightAllowsAnyLocalhostPort() throws Exception {
        mvc.perform(options("/api/me")
                        .header(HttpHeaders.ORIGIN, "http://localhost:53291")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "GET"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN,
                        "http://localhost:53291"));
    }

    @Test
    @DisplayName("허용하지 않은 오리진은 프리플라이트에서 막힌다")
    void preflightRejectsUnknownOrigin() throws Exception {
        mvc.perform(options("/api/me")
                        .header(HttpHeaders.ORIGIN, "https://evil.example.com")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "GET"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("헬스체크는 인증 없이 열려 있다 (cron 킵얼라이브가 친다)")
    void healthIsPublic() throws Exception {
        mvc.perform(get("/api/health")).andExpect(status().isOk());
    }

    @Test
    @DisplayName("빈 요청 본문은 VALIDATION_ERROR로 떨어진다")
    void validatesLoginBody() throws Exception {
        mvc.perform(post("/api/auth/kakao")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"kakaoAccessToken\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }
}
