package com.hackathonyaho.voicejournal.session.service;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

/**
 * Hume 단기 액세스 토큰 발급 (F1-13 · TC-03).
 *
 * <p><b>API 키는 앱으로 내려보내지 않는다.</b> 앱 번들에 들어가면 회수할 방법이 없고
 * 과금이 그 키에 붙는다 — 그래서 서버가 client_credentials로 30분짜리 토큰만 발급한다.
 * 하드컷이 7분이라 세션 하나에 넉넉하다.
 *
 * <p>키 두 개(API·Secret) 모두 AI가 소유한 Hume 계정에서 받는다.
 */
@Slf4j
@Service
public class HumeTokenService {

    private static final String TOKEN_URL = "https://api.hume.ai/oauth2-cc/token";
    /** Hume 문서 기준 30분. 응답에 expires_in이 없을 때만 쓴다. */
    private static final Duration DEFAULT_TTL = Duration.ofMinutes(30);

    private final RestClient client;
    private final String basicAuth;

    public HumeTokenService(@Value("${app.hume.api-key}") String apiKey,
                            @Value("${app.hume.secret-key}") String secretKey) {
        this.client = RestClient.create();
        this.basicAuth = "Basic " + Base64.getEncoder()
                .encodeToString((apiKey + ":" + secretKey).getBytes(StandardCharsets.UTF_8));
    }

    public record Token(String accessToken, Instant expiresAt) {
    }

    public Token issue() {
        try {
            Map<?, ?> body = client.post()
                    .uri(TOKEN_URL)
                    .header(HttpHeaders.AUTHORIZATION, basicAuth)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body("grant_type=client_credentials")
                    .retrieve()
                    .body(Map.class);

            Object token = body == null ? null : body.get("access_token");
            if (token == null) {
                throw new BusinessException(ErrorCode.HUME_TOKEN_ISSUE_FAILED, "no access_token in response");
            }
            Object expiresIn = body.get("expires_in");
            Duration ttl = expiresIn instanceof Number n ? Duration.ofSeconds(n.longValue()) : DEFAULT_TTL;
            return new Token(String.valueOf(token), Instant.now().plus(ttl));

        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            // 키도 토큰도 로그에 남기지 않는다.
            log.warn("hume token issue failed ({})", e.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.HUME_TOKEN_ISSUE_FAILED, "hume token issue failed");
        }
    }
}
