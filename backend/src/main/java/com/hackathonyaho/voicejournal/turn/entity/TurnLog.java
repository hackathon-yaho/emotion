package com.hackathonyaho.voicejournal.turn.entity;

import com.hackathonyaho.voicejournal.common.crypto.TranscriptConverter;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * 턴 로그 (F5-01). AI서버가 보낸 값을 <b>그대로</b> 담는다 — 백엔드는 재계산·재검증을
 * 하지 않는다(계약 §3-2).
 *
 * <p>담지 않는 것 셋 — <b>음성 원본</b>(FR-041: 필드 자체가 없다), <b>위기 판정</b>
 * ({@code crisis_event}로만 가고 {@code turn_id}를 두지 않는다), <b>thresholdMode</b>
 * (세션 단위 값이라 {@code voice_session}에 이미 있다).
 */
@Getter
@Entity
@Table(name = "turn_log")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TurnLog {

    public static final String USER = "user";
    public static final String ASSISTANT = "assistant";

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "session_id", nullable = false, columnDefinition = "uuid")
    private UUID sessionId;

    @Column(name = "turn_index", nullable = false)
    private int turnIndex;

    @Column(nullable = false)
    private String role;

    /**
     * <b>발화 시각이다 — 적재 시각이 아니다</b>(계약 §3-2 v1.5). 재시도는 최초 시도와
     * 같은 값을 보내므로, {@code unique(session_id, turn_index)} 위반이 "재시도"인지
     * "다른 발화"인지를 이 한 컬럼으로 가른다.
     */
    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    /** 변환기가 저장 시 암호화하고 조회 시 복호화한다 — 이 필드는 언제나 평문이다. */
    @Convert(converter = TranscriptConverter.class)
    @Column(name = "transcript_enc", nullable = false)
    private String transcript;

    @Column(name = "text_valence")
    private BigDecimal textValence;

    @Column(name = "voice_valence")
    private BigDecimal voiceValence;

    @Column(name = "gap")
    private BigDecimal gap;

    @Column(name = "gap_triggered", nullable = false)
    private boolean gapTriggered;

    /** 상위 5개. 디버깅·재현성 검증용이며 응답 LLM에는 들어가지 않는다(FR-025). */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "top_prosody")
    private Map<String, Double> topProsody;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public static TurnLog of(UUID sessionId, int turnIndex, String role, Instant occurredAt,
                             String transcript, BigDecimal textValence, BigDecimal voiceValence,
                             BigDecimal gap, boolean gapTriggered, Map<String, Double> topProsody) {
        TurnLog turn = new TurnLog();
        turn.sessionId = sessionId;
        turn.turnIndex = turnIndex;
        turn.role = role;
        turn.occurredAt = occurredAt;
        turn.transcript = transcript;
        turn.textValence = textValence;
        turn.voiceValence = voiceValence;
        turn.gap = gap;
        turn.gapTriggered = gapTriggered;
        turn.topProsody = topProsody;
        turn.createdAt = Instant.now();
        return turn;
    }

    /** 충돌로 재번호를 매길 때만 쓴다 (3-1 중복 적재 처리). */
    public void renumberTo(int turnIndex) {
        this.turnIndex = turnIndex;
    }
}
