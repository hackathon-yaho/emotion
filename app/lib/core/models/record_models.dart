/// 계약서 §2-9 `GET /api/sessions`.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.startedAt,
    required this.durationSec,
    required this.turnCount,
    required this.summary,
    required this.gapAvg,
    required this.tags,
  });

  final String sessionId;
  final DateTime startedAt;
  final int durationSec;
  final int turnCount;
  final String? summary;

  /// 기록 화면은 갭 노출이 허용된다 (FR-031). 목록에 표시한다 (§7-8).
  final double? gapAvg;

  /// 그 세션에서 가장 많이 등장한 상위 3개까지.
  final List<String> tags;

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        sessionId: j['sessionId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationSec: j['durationSec'] as int,
        turnCount: j['turnCount'] as int,
        summary: j['summary'] as String?,
        gapAvg: (j['gapAvg'] as num?)?.toDouble(),
        tags: (j['tags'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// 계약서 §2-10 `GET /api/sessions/{id}`.
class SessionDetail {
  const SessionDetail({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.endReason,
    required this.thresholdMode,
    required this.summary,
    required this.turns,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final String endReason;
  final String thresholdMode;
  final String? summary;
  final List<Turn> turns;

  factory SessionDetail.fromJson(Map<String, dynamic> j) => SessionDetail(
        sessionId: j['sessionId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] == null
            ? null
            : DateTime.parse(j['endedAt'] as String),
        durationSec: j['durationSec'] as int,
        endReason: j['endReason'] as String,
        thresholdMode: j['thresholdMode'] as String,
        summary: j['summary'] as String?,
        turns: (j['turns'] as List<dynamic>)
            .map((e) => Turn.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Turn {
  const Turn({
    required this.turnId,
    required this.turnIndex,
    required this.occurredAt,
    required this.role,
    required this.transcript,
    required this.textValence,
    required this.voiceValence,
    required this.gap,
    required this.gapTriggered,
    required this.tags,
  });

  final String turnId;
  final int turnIndex;
  final DateTime occurredAt;

  /// `user` | `assistant`.
  final String role;
  final String transcript;

  /// **assistant 턴은 valence·gap이 전부 null이다** — 측정 대상은 사용자
  /// 발화뿐이다 (§2-10).
  final double? textValence;
  final double? voiceValence;
  final double? gap;
  final bool gapTriggered;
  final List<String> tags;

  bool get isUser => role == 'user';

  factory Turn.fromJson(Map<String, dynamic> j) => Turn(
        turnId: j['turnId'] as String,
        turnIndex: j['turnIndex'] as int,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        role: j['role'] as String,
        transcript: j['transcript'] as String,
        textValence: (j['textValence'] as num?)?.toDouble(),
        voiceValence: (j['voiceValence'] as num?)?.toDouble(),
        gap: (j['gap'] as num?)?.toDouble(),
        gapTriggered: j['gapTriggered'] as bool? ?? false,
        tags: (j['tags'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// 계약서 §2-11 `DELETE /api/sessions/{id}`.
///
/// 앱은 이 응답을 받으면 **관찰 목록 캐시를 무효화한다.** 근거를 잃은 관찰이
/// 화면에 남아 있으면 그 순간 "근거 없는 문장"이 된다 (FR-081).
class SessionDeleteResult {
  const SessionDeleteResult({
    required this.deletedSessionId,
    required this.deletedTurnCount,
    required this.removedObservationIds,
    required this.recalculatedObservationIds,
  });

  final String deletedSessionId;
  final int deletedTurnCount;

  /// 남은 근거가 3회 미만이 되어 **삭제된** 관찰.
  final List<String> removedObservationIds;

  /// 근거는 남았으나 **숫자가 재계산된** 관찰.
  final List<String> recalculatedObservationIds;

  factory SessionDeleteResult.fromJson(Map<String, dynamic> j) =>
      SessionDeleteResult(
        deletedSessionId: j['deletedSessionId'] as String,
        deletedTurnCount: j['deletedTurnCount'] as int,
        removedObservationIds:
            (j['removedObservationIds'] as List<dynamic>? ?? const [])
                .map((e) => e as String)
                .toList(),
        recalculatedObservationIds:
            (j['recalculatedObservationIds'] as List<dynamic>? ?? const [])
                .map((e) => e as String)
                .toList(),
      );
}
