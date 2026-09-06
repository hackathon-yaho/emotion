package com.hackathonyaho.voicejournal.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;

/**
 * 앱은 GitHub Pages에 있어 오리진이 다르다. 허용하지 않으면 브라우저가 모든
 * 요청을 차단하고 <b>서버 로그에는 요청이 도달하지도 않는다</b>.
 *
 * <p><b>{@code WebMvcConfigurer}가 아니라 필터인 이유</b> (2026-09-06 수정) —
 * MVC 계층의 CORS는 요청이 {@code DispatcherServlet}까지 가야 붙는다. 그런데
 * {@link com.hackathonyaho.voicejournal.auth.security.JwtAuthFilter}는 그 앞에서
 * 401을 만들고 끝내므로 <b>인증 실패 응답에만 CORS 헤더가 빠졌다</b>.
 * 브라우저가 그 응답을 통째로 막아 앱에는 네트워크 오류로만 보이고,
 * 계약 §1-2의 {@code TOKEN_EXPIRED}를 보고 재로그인시키는 F1-02가
 * <b>영원히 안 불린다</b>. 200·400은 멀쩡한데 401만 그래서 원인 추적도 오래 걸렸다.
 *
 * <p>필터를 가장 앞에 두면 <b>정상·오류·필터가 만든 응답 전부</b>가 같은 처리를 탄다.
 * 모든 응답에 붙여야 하는 헤더는 모든 응답이 지나가는 자리에서 붙인다.
 *
 * <p>근거: {@code docs/response/app/cors-origin.md} · {@code docs/request/backend/cors-on-401.md}
 */
@Configuration
public class CorsConfig {

    private final String[] allowedOrigins;

    public CorsConfig(@Value("${cors.allowed-origins}") String[] allowedOrigins) {
        this.allowedOrigins = allowedOrigins;
    }

    @Bean
    FilterRegistrationBean<CorsFilter> corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        // allowedOrigins가 아니라 allowedOriginPatterns다 — 와일드카드 포트를 받으려면
        // 이쪽이어야 하고, 그래서 앱이 --web-port를 고정하지 않아도 된다.
        config.setAllowedOriginPatterns(List.of(allowedOrigins));
        config.setAllowedMethods(List.of("GET", "POST", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        // 앱이 쿠키를 쓰지 않고 JWT를 헤더로 보낸다. 켜면 와일드카드 오리진을 못 쓴다.
        config.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        FilterRegistrationBean<CorsFilter> registration =
                new FilterRegistrationBean<>(new CorsFilter(source));
        // 인증 필터들은 @Component 기본 등록이라 LOWEST_PRECEDENCE다. 이 값이어야
        // 그보다 먼저 돌고, 그래야 401에도 헤더가 붙는다.
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return registration;
    }
}
