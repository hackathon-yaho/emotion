package com.hackathonyaho.voicejournal.trend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * 계약 §2-8. <b>한 응답에 세 기능이 실려 있다</b> — `points`(F9-01) · `highlights`(F9-02) ·
 * `tagGaps`·`userAvgGap`(F9-03, P1). 그래서 S04는 호출이 늘지 않는다.
 *
 * <p><b>데이터 없는 날은 `points`에서 생략한다.</b> 0으로 채우거나 보간하지 않는다 —
 * 없는 감정을 그리는 것이기 때문이다(계약 §1-3).
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record TrendResponse(
        String range,
        String timezone,
        List<Point> points,
        List<Highlight> highlights,
        BigDecimal userAvgGap,
        List<TagGap> tagGaps) {

    public record Point(LocalDate date, BigDecimal textValence, BigDecimal voiceValence,
                        BigDecimal gap, int sessionCount) {
    }

    /** 갭이 임계를 넘은 <b>연속 구간</b>. 앱이 음영 처리하고 탭하면 그날 상세로 간다. */
    public record Highlight(LocalDate from, LocalDate to, String reason) {
    }

    public record TagGap(String tag, int occurrences, BigDecimal tagAvgGap) {
    }
}
