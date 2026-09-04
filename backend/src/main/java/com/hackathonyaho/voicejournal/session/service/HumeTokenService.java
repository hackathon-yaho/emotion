package com.hackathonyaho.voicejournal.session.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
    private final ObjectMapper mapper = new ObjectMapper();

    public HumeTokenService(RestClient.Builder builder,
                            @Value("${app.hume.api-key}") String apiKey,
                            @Value("${app.hume.secret-key}") String secretKey) {
        this.client = builder.build();
        this.basicAuth = "Basic " + Base64.getEncoder()
                .encodeToString((apiKey + ":" + secretKey).getBytes(StandardCharsets.UTF_8));
    }

    public record Token(String accessToken, Instant expiresAt) {
    }

    public Token issue() {
        try {
            // 본문을 String으로 받아 직접 파싱한다 — Hume은 200에 Content-Type을 안 싣는다(실측
            // 2026-09-05). 타입이 없으면 Spring이 변환기를 못 골라 UnknownContentTypeException이
            // 나고, 겉으로는 키가 틀린 것과 똑같이 503으로 보인다.
            String raw = client.post()
                    .uri(TOKEN_URL)
                    .header(HttpHeaders.AUTHORIZATION, basicAuth)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body("grant_type=client_credentials")
                    .retrieve()
                    .body(String.class);

            JsonNode body = raw == null || raw.isBlank() ? null : mapper.readTree(raw);
            JsonNode token = body == null ? null : body.get("access_token");
            if (token == null || token.asText().isBlank()) {
                throw new BusinessException(ErrorCode.HUME_TOKEN_ISSUE_FAILED, "no access_token in response");
            }
            JsonNode expiresIn = body.get("expires_in");
            Duration ttl = expiresIn != null && expiresIn.isNumber()
                    ? Duration.ofSeconds(expiresIn.asLong())
                    : DEFAULT_TTL;
            return new Token(token.asText(), Instant.now().plus(ttl));

        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            // 키도 토큰도 로그에 남기지 않는다.
            log.warn("hume token issue failed ({})", e.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.HUME_TOKEN_ISSUE_FAILED, "hume token issue failed");
        }
    }
}
