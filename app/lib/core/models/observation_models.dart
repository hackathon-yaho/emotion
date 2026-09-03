/// 계약서 §2-6 `GET /api/observations`.
///
/// **`evidence`는 목록에서도 반드시 함께 내려온다** — 관찰 문장만 있고 근거가
/// 없는 상태를 계약 수준에서 만들지 않기 위함이다 (FR-053).
class Observation {
  const Observation({
    required this.observationId,
    required this.createdAt,
    required this.sentence,
    required this.evidence,
    this.feedback,
  });

  final String observationId;
  final DateTime createdAt;
  final String sentence;
  final Evidence evidence;

  /// `agree` | `disagree` | null(미응답).
  /// **`disagree`가 관찰을 삭제하지 않는다** — 표시만 남는다 (§2-7-1).
  final String? feedback;

  bool get answered => feedback != null;

  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
        observationId: j['observationId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        sentence: j['sentence'] as String,
        evidence: Evidence.fromJson(j['evidence'] as Map<String, dynamic>),
        feedback: j['feedback'] as String?,
      );
}

class Evidence {
  const Evidence({
    required this.tag,
    required this.occurrences,
    required this.tagAvgGap,
    required this.userAvgGap,
    required this.ratio,
  });

  final String tag;
  final int occurrences;
  final double tagAvgGap;
  final double userAvgGap;
  final double ratio;

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        tag: j['tag'] as String,
        occurrences: j['occurrences'] as int,
        tagAvgGap: (j['tagAvgGap'] as num).toDouble(),
        userAvgGap: (j['userAvgGap'] as num).toDouble(),
        ratio: (j['ratio'] as num).toDouble(),
      );
}

/// 계약서 §2-7 `GET /api/observations/{id}/evidence`.
///
/// **`turns` 길이는 `evidence.occurrences`와 반드시 같다.** 다르면 계약 위반이며
/// PRD §1.4의 "evidence 불일치 0건" 지표 실패로 집계한다.
class ObservationEvidence {
  const ObservationEvidence({
    required this.observationId,
    required this.sentence,
    required this.evidence,
    required this.turns,
  });

  final String observationId;
  final String sentence;
  final Evidence evidence;
  final List<EvidenceTurn> turns;

  /// 계약 위반 감지 — 화면에 그리기 전에 확인한다.
  bool get isConsistent => turns.length == evidence.occurrences;

  factory ObservationEvidence.fromJson(Map<String, dynamic> j) =>
      ObservationEvidence(
        observationId: j['observationId'] as String,
        sentence: j['sentence'] as String,
        evidence: Evidence.fromJson(j['evidence'] as Map<String, dynamic>),
        turns: (j['turns'] as List<dynamic>)
            .map((e) => EvidenceTurn.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class EvidenceTurn {
  const EvidenceTurn({
    required this.turnId,
    required this.sessionId,
    required this.occurredAt,
    required this.transcript,
    required this.textValence,
    required this.voiceValence,
    required this.gap,
  });

  final String turnId;
  final String sessionId;
  final DateTime occurredAt;
  final String transcript;

  /// null = "측정하지 못했다". 0으로 대체하지 않는다 (§1-3).
  final double? textValence;
  final double? voiceValence;
  final double? gap;

  factory EvidenceTurn.fromJson(Map<String, dynamic> j) => EvidenceTurn(
        turnId: j['turnId'] as String,
        sessionId: j['sessionId'] as String,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        transcript: j['transcript'] as String,
        textValence: (j['textValence'] as num?)?.toDouble(),
        voiceValence: (j['voiceValence'] as num?)?.toDouble(),
        gap: (j['gap'] as num?)?.toDouble(),
      );
}

abstract final class FeedbackValue {
  static const agree = 'agree';
  static const disagree = 'disagree';
}
