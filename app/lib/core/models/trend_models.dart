/// 계약서 §2-8 `GET /api/trend`.
class Trend {
  const Trend({
    required this.range,
    required this.timezone,
    required this.points,
    required this.highlights,
    this.userAvgGap,
    this.tagGaps = const [],
  });

  final String range;
  final String timezone;

  /// **기록이 없는 날은 배열에 아예 없다.** 0으로 채우거나 앞뒤를 이어
  /// 보간하지 않는다 — 없는 감정을 그리는 것이기 때문이다 (§1-3).
  final List<TrendPoint> points;

  /// 갭이 임계를 넘은 **연속 구간**. 앱은 음영 처리하고, 탭하면 그날의 대화
  /// 상세로 이동한다 (F9-02).
  final List<TrendHighlight> highlights;

  /// 그 사용자 **전 기간** 평균 갭 (v1.4 §2-8). `tagGaps` 막대의 기준선이고,
  /// 앱이 ×1.5를 곱해 판정선을 그린다. 기록이 없으면 null이다.
  final double? userAvgGap;

  /// 이야기별 갭 (F9-03, v1.4 §2-8). **`range`에 종속**되고 서버가 3회 미만을
  /// 걸러 `tagAvgGap` 내림차순 상위 7개까지 준다. 없으면 빈 배열.
  final List<TagGap> tagGaps;

  factory Trend.fromJson(Map<String, dynamic> j) => Trend(
        range: j['range'] as String,
        timezone: j['timezone'] as String? ?? 'Asia/Seoul',
        points: (j['points'] as List<dynamic>)
            .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        highlights: (j['highlights'] as List<dynamic>? ?? const [])
            .map((e) => TrendHighlight.fromJson(e as Map<String, dynamic>))
            .toList(),
        userAvgGap: (j['userAvgGap'] as num?)?.toDouble(),
        tagGaps: (j['tagGaps'] as List<dynamic>? ?? const [])
            .map((e) => TagGap.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.textValence,
    required this.voiceValence,
    required this.gap,
    required this.sessionCount,
  });

  /// KST 기준 일자 (`2026-09-12`).
  final String date;

  /// −1.00 ~ 1.00. null이면 그 계열의 점을 찍지 않는다.
  final double? textValence;
  final double? voiceValence;

  /// 둘 중 하나라도 null이면 null (§1-3).
  final double? gap;

  /// 하루에 2세션 이상이면 그날의 평균.
  final int sessionCount;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        date: j['date'] as String,
        textValence: (j['textValence'] as num?)?.toDouble(),
        voiceValence: (j['voiceValence'] as num?)?.toDouble(),
        gap: (j['gap'] as num?)?.toDouble(),
        sessionCount: j['sessionCount'] as int? ?? 1,
      );
}

class TrendHighlight {
  const TrendHighlight({
    required this.from,
    required this.to,
    required this.reason,
  });

  final String from;
  final String to;
  final String reason;

  factory TrendHighlight.fromJson(Map<String, dynamic> j) => TrendHighlight(
        from: j['from'] as String,
        to: j['to'] as String,
        reason: j['reason'] as String? ?? 'gap_exceeded',
      );
}

abstract final class TrendRange {
  static const d7 = '7d';
  static const d30 = '30d';
  static const d90 = '90d';
}

/// 이야기별 갭 한 줄 (계약 §2-8, v1.4).
class TagGap {
  const TagGap({
    required this.tag,
    required this.occurrences,
    required this.tagAvgGap,
  });

  final String tag;
  final int occurrences;
  final double tagAvgGap;

  factory TagGap.fromJson(Map<String, dynamic> j) => TagGap(
        tag: j['tag'] as String,
        occurrences: j['occurrences'] as int? ?? 0,
        tagAvgGap: (j['tagAvgGap'] as num).toDouble(),
      );
}
