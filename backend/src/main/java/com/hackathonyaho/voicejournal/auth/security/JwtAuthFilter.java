package com.hackathonyaho.voicejournal.auth.security;

import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.ErrorWriter;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.ExpiredJwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Set;
import java.util.UUID;

/**
 * {@code Authorization: Bearer <JWT>} 검증 (계약 §1-1).
 *
 * <p>인증 제외는 <b>경로와 메서드 두 축</b>이다 — 경로만으로 관리하면
 * CORS 프리플라이트가 막힌다 (아래).
 */
@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    /** 계약 §1-1 — 이 둘만 인증 없이 통과한다. */
    private static final Set<String> PUBLIC_PATHS = Set.of("/api/auth/kakao", "/api/health");

    private final JwtProvider jwtProvider;
    private final ObjectMapper objectMapper;

    /**
     * <b>OPTIONS는 메서드 전체를 제외한다.</b> CORS 프리플라이트에는
     * {@code Authorization} 헤더가 실리지 않아, 경로 기반 예외만 두면 401로 막힌다.
     * 그 실패는 앱에서 그냥 네트워크 오류로 보이고 서버에는 401만 남아
     * 원인이 CORS라는 걸 알아채는 데 한참 걸린다.
     */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return HttpMethod.OPTIONS.matches(request.getMethod())
                || PUBLIC_PATHS.contains(request.getRequestURI())
                // AI서버는 JWT가 없다. 인증은 InternalAuthFilter가 공유 시크릿으로 한다(계약 §3-1).
                || request.getRequestURI().startsWith("/internal/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            reject(response, ErrorCode.UNAUTHORIZED);
            return;
        }
        try {
            UUID profileId = jwtProvider.parseProfileId(header.substring(7));
            ProfileContext.set(profileId);
            chain.doFilter(request, response);
        } catch (ExpiredJwtException e) {
            // 앱은 이 코드를 보고 카카오 재로그인으로 갱신한다.
            reject(response, ErrorCode.TOKEN_EXPIRED);
        } catch (Exception e) {
            reject(response, ErrorCode.UNAUTHORIZED);
        } finally {
            ProfileContext.clear();
        }
    }

    /** 필터 단계라 GlobalExceptionHandler를 못 타므로 같은 모양을 직접 만든다 (계약 §1-2). */
    private void reject(HttpServletResponse response, ErrorCode code) throws IOException {
        ErrorWriter.write(response, objectMapper, code);
    }
}
