package com.hackathonyaho.voicejournal.auth.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hackathonyaho.voicejournal.common.global.ErrorCode;
import com.hackathonyaho.voicejournal.common.global.ErrorWriter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * {@code /internal/**} 전용 인증 (계약 §3-1). AI서버 → 백엔드 호출은 JWT가 아니라
 * 공유 시크릿 하나로 통과한다.
 *
 * <p>시크릿은 <b>환경변수로만</b> 주입한다. 저장소에 넣지 않는다.
 */
@Component
public class InternalAuthFilter extends OncePerRequestFilter {

    private static final String HEADER = "X-Internal-Secret";

    private final byte[] expected;
    private final ObjectMapper objectMapper;

    public InternalAuthFilter(@Value("${app.internal.shared-secret}") String sharedSecret,
                              ObjectMapper objectMapper) {
        this.expected = sharedSecret.getBytes(StandardCharsets.UTF_8);
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/internal/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String provided = request.getHeader(HEADER);
        // 길이·내용을 한 번에 비교한다 — 앞자리부터 틀린 지점을 되돌려주지 않는다.
        if (provided == null
                || !MessageDigest.isEqual(provided.getBytes(StandardCharsets.UTF_8), expected)) {
            ErrorWriter.write(response, objectMapper, ErrorCode.INTERNAL_AUTH_FAILED);
            return;
        }
        chain.doFilter(request, response);
    }
}
