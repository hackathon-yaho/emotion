/// 계약서 §2-13 `GET /api/session/{sessionId}/live` (v1.3 신설).
///
/// **S02 화면에서만 폴링한다.** 대화 종료·화면 이탈 시 멈춘다. 간격은
/// `SessionStart.livePollIntervalSec`를 따르고 앱에 상수로 박지 않는다.
class LiveSignal {
  const LiveSignal({
    required this.sessionId,
    required this.lastTurnIndex,
    required this.crisisDetected,
    required this.turns,
  });

  final String sessionId;

  /// 다음 폴링의 `sinceTurnIndex`로 쓴다.
  final int lastTurnIndex;

  /// **세션 단위 boolean.** turn 단위로 묶지 않는다 — `crisis_event`에
  /// `turn_id`를 두지 않은 것과 같은 이유다.
  ///
  /// 앱은 `false → true` **전이에서 한 번만** S07을 띄운다. 이후 폴링에서
  /// 계속 true로 오더라도 다시 띄우지 않는다.
  final bool crisisDetected;

  /// **`demoMode == true`일 때만 채워진다.**
  ///
  /// 비데모 세션에서는 항상 빈 배열이다 — 서버가 `null`로 마스킹하지 않는
  /// 이유는 §1-3의 `null`("측정하지 못했다")과 뜻이 섞이지 않게 하기
  /// 위함이다. **빈 배열은 "볼 권한이 없다"이지 "값이 없다"가 아니다.**
  final List<LiveTurn> turns;

  /// `transcript`는 오지 않는다 — 앱은 EVI에서 이미 텍스트를 받고 있고,
  /// 넣으면 노출면만 늘어난다.
  factory LiveSignal.fromJson(Map<String, dynamic> j) => LiveSignal(
        sessionId: j['sessionId'] as String,
        lastTurnIndex: j['lastTurnIndex'] as int? ?? -1,
        crisisDetected: j['crisisDetected'] as bool? ?? false,
        turns: (j['turns'] as List<dynamic>? ?? const [])
            .map((e) => LiveTurn.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// 데모 모드에서만 오는 턴별 측정값.
///
/// **이 값들을 S02에 그리는 것은 `demoMode == true`일 때뿐이다** (FR-031).
class LiveTurn {
  const LiveTurn({
    required this.turnIndex,
    required this.textValence,
    required this.voiceValence,
    required this.gap,
    required this.gapTriggered,
  });

  final int turnIndex;

  /// null = 측정하지 못했다 (§1-3).
  final double? textValence;
  final double? voiceValence;
  final double? gap;
  final bool gapTriggered;

  factory LiveTurn.fromJson(Map<String, dynamic> j) => LiveTurn(
        turnIndex: j['turnIndex'] as int,
        textValence: (j['textValence'] as num?)?.toDouble(),
        voiceValence: (j['voiceValence'] as num?)?.toDouble(),
        gap: (j['gap'] as num?)?.toDouble(),
        gapTriggered: j['gapTriggered'] as bool? ?? false,
      );
}
