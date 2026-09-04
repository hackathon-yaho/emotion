package com.hackathonyaho.voicejournal.session.service;

import com.hackathonyaho.voicejournal.common.global.SessionRef;
import com.hackathonyaho.voicejournal.turn.repository.TurnLogRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 세션 요약 생성 (계약 §3-5). 백엔드 → AI서버, <b>동기 호출·타임아웃 3초</b>.
 *
 * <p><b>실패하면 재시도하지 않고 null이다.</b> 요약은 있으면 좋은 것이고, 대화 기록
 * 자체는 이미 남아 있다(계약 §2-5). 종료 응답을 3초씩 여러 번 붙잡을 이유가 없다.
 *
 * <p><b>보내는 것은 턴 텍스트뿐이다</b> — valence·갭·태그를 보내지 않는다. 요약에
 * 수치가 섞이면 S02-1이 갭을 노출하는 셈이 된다(FR-031 취지).
 */
@Slf4j
@Component
public class SummaryClient {

    private final TurnLogRepository turnLogRepository;
    private final RestClient client;
    private final String sharedSecret;

    public SummaryClient(TurnLogRepository turnLogRepository,
                         @Value("${app.ai.base-url}") String baseUrl,
                         @Value("${app.ai.summary-timeout-ms}") int timeoutMs,
                         @Value("${app.internal.shared-secret}") String sharedSecret) {
        this.turnLogRepository = turnLogRepository;
        this.sharedSecret = sharedSecret;

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofMillis(timeoutMs));
        factory.setReadTimeout(Duration.ofMillis(timeoutMs));
        this.client = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    /** 요약 문장, 실패하면 null. <b>예외를 밖으로 내보내지 않는다</b> — 종료는 성립해야 한다. */
    public String generate(UUID sessionId) {
        List<Map<String, String>> turns = turnLogRepository.findBySessionIdOrderByTurnIndex(sessionId)
                .stream()
                .map(t -> Map.of("role", t.getRole(), "transcript", t.getTranscript()))
                .toList();

        if (turns.isEmpty()) {
            // 요약할 발화가 없다. 호출 자체를 하지 않는다.
            return null;
        }

        try {
            Map<?, ?> body = client.post()
                    .uri("/internal/summaries")
                    .header("X-Internal-Secret", sharedSecret)
                    .body(Map.of("sessionId", sessionId.toString(), "turns", turns))
                    .retrieve()
                    .body(Map.class);

            Object summary = body == null ? null : body.get("summary");
            return summary == null ? null : String.valueOf(summary);

        } catch (Exception e) {
            // 발화도 sessionId도 남기지 않는다 — sessionRef로만 묶는다 (FR-092).
            log.warn("summary generation failed [{}] ({})",
                    SessionRef.of(sessionId.toString()), e.getClass().getSimpleName());
            return null;
        }
    }
}
