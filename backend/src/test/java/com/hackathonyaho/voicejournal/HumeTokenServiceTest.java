package com.hackathonyaho.voicejournal;

import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import com.hackathonyaho.voicejournal.session.service.HumeTokenService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;

/**
 * Hume 토큰 발급 (F1-13).
 *
 * <p><b>왜 이 테스트가 있나</b> — Hume의 토큰 엔드포인트는 <b>200에 {@code Content-Type}을
 * 싣지 않는다</b>(2026-09-05 실측). 응답을 {@code Map}으로 받으면 Spring이 변환기를 못 골라
 * {@code UnknownContentTypeException}이 나고, 겉으로는 <b>키가 틀린 것과 똑같이 503</b>으로
 * 보인다. 배포 후에 만났으면 키부터 의심했을 결함이라 여기서 고정한다.
 */
class HumeTokenServiceTest {

    private static final String BODY = """
            {"token_type":"Bearer","access_token":"tok_abc","grant_type":"client_credentials","expires_in":1799}
            """;

    private record Fixture(HumeTokenService service, MockRestServiceServer server) {
    }

    private Fixture fixture() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        return new Fixture(new HumeTokenService(builder, "api-key", "secret-key"), server);
    }

    @Test
    @DisplayName("Content-Type 없는 200도 읽는다 — Hume이 실제로 그렇게 준다")
    void parsesResponseWithoutContentType() {
        Fixture f = fixture();
        f.server().expect(requestTo("https://api.hume.ai/oauth2-cc/token"))
                .andExpect(method(org.springframework.http.HttpMethod.POST))
                .andExpect(header("Authorization", "Basic YXBpLWtleTpzZWNyZXQta2V5"))
                .andExpect(content().string("grant_type=client_credentials"))
                // Content-Type을 일부러 붙이지 않는다. 이게 실물이다.
                .andRespond(withStatus(HttpStatus.OK).body(BODY));

        HumeTokenService.Token token = f.service().issue();

        assertThat(token.accessToken()).isEqualTo("tok_abc");
        // expires_in 1799초를 그대로 쓴다 — 기본값 30분으로 떨어지지 않는다.
        assertThat(token.expiresAt()).isBetween(
                Instant.now().plusSeconds(1700), Instant.now().plusSeconds(1799));
        f.server().verify();
    }

    @Test
    @DisplayName("access_token이 없으면 503으로 올린다 — 200이어도 토큰이 없으면 실패다")
    void failsWhenTokenMissing() {
        Fixture f = fixture();
        f.server().expect(requestTo("https://api.hume.ai/oauth2-cc/token"))
                .andRespond(withStatus(HttpStatus.OK).body("{\"token_type\":\"Bearer\"}"));

        assertThatThrownBy(() -> f.service().issue())
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("no access_token");
    }

    @Test
    @DisplayName("키가 틀리면 503이다 — 예외 메시지에 키가 실리지 않는다")
    void failsOnUnauthorized() {
        Fixture f = fixture();
        f.server().expect(requestTo("https://api.hume.ai/oauth2-cc/token"))
                .andRespond(withStatus(HttpStatus.UNAUTHORIZED));

        assertThatThrownBy(() -> f.service().issue())
                .isInstanceOf(BusinessException.class)
                .hasMessageNotContaining("secret-key")
                .hasMessageNotContaining("api-key");
    }
}
