package com.hackathonyaho.voicejournal.auth.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * 자체 JWT 발급·검증 (F1-02).
 *
 * <p><b>subject는 profileId다.</b> kakaoId를 넣지 않는다 — 토큰이 새면
 * 식별자 분리(PRD §5.1)가 토큰 하나로 무너진다.
 *
 * <p>리프레시 토큰을 두지 않는다. 만료 7일이고 만료되면 카카오 재로그인이다
 * (계약 §1-1, spec F1-02).
 */
@Component
public class JwtProvider {

    private final SecretKey key;
    private final long expiryDays;

    public JwtProvider(@Value("${app.jwt.secret}") String secret,
                       @Value("${app.jwt.expiry-days}") long expiryDays) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiryDays = expiryDays;
    }

    public Issued issue(UUID profileId) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(expiryDays, ChronoUnit.DAYS);
        String token = Jwts.builder()
                .subject(profileId.toString())
                .issuedAt(java.util.Date.from(now))
                .expiration(java.util.Date.from(expiresAt))
                .signWith(key)
                .compact();
        return new Issued(token, expiresAt);
    }

    /**
     * @return 검증된 profileId
     * @throws ExpiredJwtException 만료 — 호출부가 TOKEN_EXPIRED로 구분한다
     * @throws JwtException        그 외 위조·형식 오류
     */
    public UUID parseProfileId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return UUID.fromString(claims.getSubject());
    }

    public record Issued(String token, Instant expiresAt) {
    }
}
