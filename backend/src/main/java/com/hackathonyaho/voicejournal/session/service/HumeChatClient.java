package com.hackathonyaho.voicejournal.session.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.OptionalInt;

/**
 * Hume에 <b>지금 살아 있는 채팅 수</b>를 묻는다 (계약 §2-14 정원 판정).
 *
 * <p><b>왜 우리 세션 행을 세지 않는가</b> — Hume은 비활성 2분이면 채팅을 닫는데
 * {@code voice_session}은 30분을 열어 둔다(F2-06). 우리 행을 세면 <b>실제로 비어 있는
 * 자리를 두고 사람을 돌려보낸다.</b> Hume이 E0700을 판정하는 그 숫자를 그대로 본다.
 *
 * <p><b>실패하면 비어 있다고 본다(fail-open).</b> 조회가 죽었다고 대화를 막을 이유가
 * 없다 — 정원을 넘겨 붙으면 Hume이 E0700으로 거절하고, 그건 앱이 처리한다.
 */
@Slf4j
@Service
public class HumeChatClient {

    private static final String CHATS_URL = "https://api.hume.ai/v0/evi/chats?status=ACTIVE&page_size=";

    private final RestClient client;
    private final String apiKey;
    private final ObjectMapper mapper = new ObjectMapper();

    public HumeChatClient(RestClient.Builder builder,
                          @Value("${app.hume.api-key}") String apiKey) {
        this.client = builder.build();
        this.apiKey = apiKey;
    }

    /**
     * @param pageSize 셀 상한. 정원만큼만 받으면 "찼는지"를 판단하는 데 충분하다.
     * @return 활성 채팅 수. 조회에 실패하면 {@link OptionalInt#empty()}
     */
    public OptionalInt activeCount(int pageSize) {
        try {
            String raw = client.get()
                    .uri(CHATS_URL + pageSize)
                    .header("X-Hume-Api-Key", apiKey)
                    .retrieve()
                    .body(String.class);

            JsonNode page = raw == null || raw.isBlank() ? null : mapper.readTree(raw).get("chats_page");
            return page == null || !page.isArray() ? OptionalInt.empty() : OptionalInt.of(page.size());

        } catch (Exception e) {
            // 키도 채팅 식별자도 남기지 않는다.
            log.warn("hume active chat lookup failed ({})", e.getClass().getSimpleName());
            return OptionalInt.empty();
        }
    }
}
