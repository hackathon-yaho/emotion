package com.hackathonyaho.voicejournal.turn.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * 태그 저장 (F6-03). <b>백엔드는 태그를 추가·수정·재검증하지 않는다</b>(계약 §3-2) —
 * 원문 대조(F6-02)는 AI서버가 이미 끝냈다. 여기서 한 번 더 거르면 같은 규칙이 두 곳에
 * 생기고, 어긋나는 순간 §1.4 "원문 외 태그 0건" 지표의 근거가 어디인지 알 수 없어진다.
 *
 * <p>엔티티를 만들지 않는 이유는 Phase 3이 <b>쓰기만 하기</b> 때문이다. Phase 4의 집계는
 * {@code group by tag} SQL이라 어차피 엔티티를 거치지 않는다.
 */
@Component
@RequiredArgsConstructor
public class TurnTagRepository {

    private final JdbcTemplate jdbc;

    public void saveAll(UUID turnId, List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            // 태그 0개인 턴도 turn_log는 저장된다 — F7 집계에서만 빠지고
            // valence·갭 통계에는 포함된다 (spec F6-03).
            return;
        }
        jdbc.batchUpdate(
                "insert into turn_tag (turn_id, tag) values (?, ?) on conflict do nothing",
                tags.stream().distinct().map(tag -> new Object[]{turnId, tag}).toList());
    }
}
