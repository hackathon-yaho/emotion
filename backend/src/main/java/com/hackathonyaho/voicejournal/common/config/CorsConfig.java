package com.hackathonyaho.voicejournal.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 앱은 GitHub Pages에 있어 오리진이 다르다. 허용하지 않으면 브라우저가 모든
 * 요청을 차단하고 <b>서버 로그에는 요청이 도달하지도 않는다</b>.
 *
 * <p>근거: {@code docs/response/app/cors-origin.md}
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    private final String[] allowedOrigins;

    public CorsConfig(@Value("${cors.allowed-origins}") String[] allowedOrigins) {
        this.allowedOrigins = allowedOrigins;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                // allowedOrigins가 아니라 allowedOriginPatterns다 — 와일드카드 포트를
                // 받으려면 이쪽이어야 하고, 그래서 앱이 --web-port를 고정하지 않아도 된다.
                .allowedOriginPatterns(allowedOrigins)
                .allowedMethods("GET", "POST", "DELETE", "OPTIONS")
                .allowedHeaders("Authorization", "Content-Type")
                // 앱이 쿠키를 쓰지 않고 JWT를 헤더로 보낸다. 켜면 와일드카드 오리진을 못 쓴다.
                .allowCredentials(false);
    }
}
