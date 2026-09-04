package com.hackathonyaho.voicejournal.observation.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * 관찰 (F7). <b>아래 5개(tag·occurrences·tagAvgGap·userAvgGap·ratio)가 계약 §2-6의
 * {@code evidence} 객체 그대로다.</b>
 *
 * <p><b>문장 ↔ 숫자 불일치는 0건이어야 한다</b>(§1.4 핵심 지표). AI가 돌려준 문장의
 * 숫자를 다시 파싱해 검증하지 않는다 — 우리가 보낸 숫자를 그대로 저장하므로 불일치가
 * 생길 경로 자체가 없다.
 */
@Getter
@Entity
@Table(name = "observation")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Observation {

    public static final String ACTIVE = "active";
    public static final String INVALIDATED = "invalidated";

    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "profile_id", nullable = false, columnDefinition = "uuid")
    private UUID profileId;

    /** AI서버가 쓴 문장. 실패하면 관찰 자체를 만들지 않는다 — 템플릿으로 대체하지 않는다. */
    @Column(nullable = false)
    private String sentence;

    @Column(nullable = false)
    private String tag;

    @Column(nullable = false)
    private int occurrences;

    @Column(name = "tag_avg_gap", nullable = false)
    private BigDecimal tagAvgGap;

    @Column(name = "user_avg_gap", nullable = false)
    private BigDecimal userAvgGap;

    @Column(nullable = false)
    private BigDecimal ratio;

    @Column(nullable = false)
    private String status;

    @Column
    private String feedback;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public static Observation of(UUID profileId, String sentence, String tag, int occurrences,
                                 BigDecimal tagAvgGap, BigDecimal userAvgGap, BigDecimal ratio) {
        Observation observation = new Observation();
        observation.profileId = profileId;
        observation.sentence = sentence;
        observation.tag = tag;
        observation.occurrences = occurrences;
        observation.tagAvgGap = tagAvgGap;
        observation.userAvgGap = userAvgGap;
        observation.ratio = ratio;
        observation.status = ACTIVE;
        observation.createdAt = Instant.now();
        return observation;
    }
}
