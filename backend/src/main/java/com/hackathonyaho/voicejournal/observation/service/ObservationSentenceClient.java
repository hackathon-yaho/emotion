package com.hackathonyaho.voicejournal.observation.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.Map;

/**
 * 관찰 문장화 (계약 §3-3). 백엔드 → AI서버.
 *
 * <p><b>보내는 것은 숫자와 태그뿐이다.</b> 원본 대화·발화·turn ID를 넣지 않는다 —
 * LLM은 표현만 담당하고 <b>패턴의 존재·강도는 코드가 판정한다</b>(FR-054, 백엔드
 * 절대 원칙 1번).
 *
 * <p><b>실패하면 null이다. 템플릿 문장으로 대체하지 않는다</b> — 표현이 어색한 것보다
 * 근거 없는 문장이 나가는 쪽이 위험하다. 관찰을 만들지 않으면 다음 주기에 다시 시도된다.
 */
@Slf4j
@Component
public class ObservationSentenceClient {

    private final RestClient client;
    private final String sharedSecret;

    public ObservationSentenceClient(@Value("${app.ai.base-url}") String baseUrl,
                                     @Value("${app.ai.observation-timeout-ms}") int timeoutMs,
                                     @Value("${app.internal.shared-secret}") String sharedSecret) {
        this.sharedSecret = sharedSecret;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofMillis(timeoutMs));
        factory.setReadTimeout(Duration.ofMillis(timeoutMs));
        this.client = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    public String sentenceFor(String tag, int occurrences, BigDecimal tagAvgGap,
                              BigDecimal userAvgGap, BigDecimal ratio) {
        try {
            Map<?, ?> body = client.post()
                    .uri("/internal/observations")
                    .header("X-Internal-Secret", sharedSecret)
                    .body(Map.of(
                            "tag", tag,
                            "occurrences", occurrences,
                            "tagAvgGap", tagAvgGap,
                            "userAvgGap", userAvgGap,
                            "ratio", ratio))
                    .retrieve()
                    .body(Map.class);

            Object sentence = body == null ? null : body.get("sentence");
            return sentence == null || String.valueOf(sentence).isBlank() ? null : String.valueOf(sentence);

        } catch (Exception e) {
            // 태그는 발화에서 온 표현이라 로그에 남기지 않는다 (FR-092·§1.4).
            log.warn("observation sentence failed ({})", e.getClass().getSimpleName());
            return null;
        }
    }
}
