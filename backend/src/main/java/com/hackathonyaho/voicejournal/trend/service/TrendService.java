package com.hackathonyaho.voicejournal.trend.service;

import com.hackathonyaho.voicejournal.auth.entity.UserBaseline;
import com.hackathonyaho.voicejournal.auth.repository.UserBaselineRepository;
import com.hackathonyaho.voicejournal.trend.dto.TrendResponse;
import com.hackathonyaho.voicejournal.trend.repository.TrendRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** F9-01·02·03. 계약 §2-8이 응답의 단일 출처다. */
@Service
@RequiredArgsConstructor
public class TrendService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final String DEFAULT_RANGE = "30d";
    private static final Map<String, Integer> RANGE_DAYS = Map.of("7d", 7, "30d", 30, "90d", 90);
    private static final String GAP_EXCEEDED = "gap_exceeded";

    private final TrendRepository trendRepository;
    private final UserBaselineRepository baselineRepository;

    @Transactional(readOnly = true)
    public TrendResponse trend(UUID profileId, String requestedRange) {
        // 모르는 값은 400으로 끊지 않고 기본값으로 본다 — 화면이 빈 채로 뜨는 편이 낫다.
        // null을 먼저 거른다: Map.of()는 containsKey(null)에서 예외를 던지고,
        // range 생략이 가장 흔한 호출이라 그대로 두면 기본 경로가 500이 된다.
        String range = requestedRange != null && RANGE_DAYS.containsKey(requestedRange)
                ? requestedRange : DEFAULT_RANGE;
        Instant from = LocalDate.now(KST).minusDays(RANGE_DAYS.get(range) - 1L)
                .atStartOfDay(KST).toInstant();

        List<TrendRepository.DayPoint> days = trendRepository.dailyPoints(profileId, from);

        return new TrendResponse(
                range,
                KST.getId(),
                days.stream()
                        .map(d -> new TrendResponse.Point(d.date(), round(d.textValence()),
                                round(d.voiceValence()), round(d.gap()), d.sessionCount()))
                        .toList(),
                highlights(days),
                // 관찰 evidence·트렌드가 같은 값을 보여야 한다 — 여기서 다시 계산하지 않는다.
                baselineRepository.findById(profileId).map(UserBaseline::getAvgGap).orElse(null),
                trendRepository.tagGaps(profileId, from).stream()
                        .map(t -> new TrendResponse.TagGap(t.tag(), t.occurrences(), round(t.tagAvgGap())))
                        .toList());
    }

    /**
     * 갭이 <b>그날 실제로 적용됐던 임계값</b>을 넘은 날들을 이어 구간으로 만든다.
     *
     * <p><b>기준이 스냅샷인 이유</b> — 임계값의 초기 수치는 20쌍 측정 후 확정된다
     * (PRD §14-5). 현재값으로 소급 판정하면 그 순간 <b>과거 날짜의 음영이 통째로
     * 달라지고</b>, 그날 앱이 실제로 되물었던 근거(FR-022)와 화면이 어긋난다.
     *
     * <p><b>기록이 없는 날에서 구간이 끊긴다.</b> 이어 붙이면 대화가 없던 날까지
     * "갭이 높았던 기간"으로 칠하게 된다 — 없는 감정을 그리지 않는다는 §1-3과 같은 이유다.
     */
    private List<TrendResponse.Highlight> highlights(List<TrendRepository.DayPoint> days) {
        List<TrendResponse.Highlight> highlights = new ArrayList<>();
        LocalDate start = null;
        LocalDate previous = null;

        for (TrendRepository.DayPoint day : days) {
            boolean exceeded = day.dayThreshold() != null && day.gap() != null
                    && day.gap().compareTo(day.dayThreshold()) >= 0;

            if (exceeded && start != null && day.date().equals(previous.plusDays(1))) {
                previous = day.date();
                continue;
            }
            if (start != null) {
                highlights.add(new TrendResponse.Highlight(start, previous, GAP_EXCEEDED));
                start = null;
            }
            if (exceeded) {
                start = day.date();
                previous = day.date();
            }
        }
        if (start != null) {
            highlights.add(new TrendResponse.Highlight(start, previous, GAP_EXCEEDED));
        }
        return highlights;
    }

    /** 계약 §1-1 — valence·gap·ratio는 소수 2자리 반올림해서 응답한다. */
    private BigDecimal round(BigDecimal value) {
        return value == null ? null : value.setScale(2, RoundingMode.HALF_UP);
    }
}
