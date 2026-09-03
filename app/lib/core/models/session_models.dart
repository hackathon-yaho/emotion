/// 계약서 §2-4 `POST /api/session/start`.
class SessionStart {
  const SessionStart({
    required this.sessionId,
    required this.humeAccessToken,
    required this.humeTokenExpiresAt,
    required this.thresholdMode,
    required this.gapThreshold,
    required this.softWrapSec,
    required this.hardCutSec,
    required this.demoMode,
    required this.humeConfigId,
    required this.livePollIntervalSec,
  });

  final String sessionId;
  final String humeAccessToken;
  final DateTime humeTokenExpiresAt;

  /// `fixed`(세션 5회 미만) | `personal`(5회 이상).
  final String thresholdMode;

  /// 이번 세션에 적용되는 실제 임계값.
  /// **앱은 표시하지 않고 데모 모드에서만 참고한다** (§2-4).
  final double gapThreshold;

  /// 5분 · 7분. **서버가 내려주는 값을 쓰고 앱에 상수로 박지 않는다** (§2-4).
  final int softWrapSec;
  final int hardCutSec;

  final bool demoMode;

  /// EVI handshake의 `config_id` (계약 v1.3 §2-4).
  ///
  /// **null이 될 수 없다** — 백엔드가 환경변수를 기동 시 fail-fast로 검증하므로
  /// 런타임에는 항상 값이 있다. 앱은 폴백을 두지 않는다.
  final String humeConfigId;

  /// `GET /api/session/{id}/live` 폴링 간격(초). 기본 2.
  /// **앱에 상수로 박지 않는다** — 서버가 내려주는 값을 쓴다 (§2-4).
  final int livePollIntervalSec;

  factory SessionStart.fromJson(Map<String, dynamic> j) => SessionStart(
        sessionId: j['sessionId'] as String,
        humeAccessToken: j['humeAccessToken'] as String,
        humeTokenExpiresAt: DateTime.parse(j['humeTokenExpiresAt'] as String),
        thresholdMode: j['thresholdMode'] as String,
        gapThreshold: (j['gapThreshold'] as num).toDouble(),
        softWrapSec: j['softWrapSec'] as int,
        hardCutSec: j['hardCutSec'] as int,
        demoMode: j['demoMode'] as bool? ?? false,
        humeConfigId: j['humeConfigId'] as String,
        livePollIntervalSec: j['livePollIntervalSec'] as int? ?? 2,
      );
}

/// 계약서 §2-5-1 `POST /api/session/{id}/resume` (P1).
class SessionResume {
  const SessionResume({
    required this.sessionId,
    required this.humeAccessToken,
    required this.resumedChatGroupId,
    required this.remainingSec,
    required this.thresholdMode,
    required this.gapThreshold,
    required this.demoMode,
    required this.humeConfigId,
  });

  final String sessionId;
  final String humeAccessToken;

  /// EVI handshake의 `resumed_chat_group_id` — 이전 맥락이 복원된다.
  final String resumedChatGroupId;

  /// `hardCutSec − usedSec`. **새 7분을 주지 않는다** (NFR-06).
  final int remainingSec;

  final String thresholdMode;
  final double gapThreshold;
  final bool demoMode;

  /// 재연결도 **같은 Config로** 붙어야 CLM이 이어진다 (회신 3번).
  final String humeConfigId;

  factory SessionResume.fromJson(Map<String, dynamic> j) => SessionResume(
        sessionId: j['sessionId'] as String,
        humeAccessToken: j['humeAccessToken'] as String,
        resumedChatGroupId: j['resumedChatGroupId'] as String,
        remainingSec: j['remainingSec'] as int,
        thresholdMode: j['thresholdMode'] as String,
        gapThreshold: (j['gapThreshold'] as num).toDouble(),
        demoMode: j['demoMode'] as bool? ?? false,
        humeConfigId: j['humeConfigId'] as String,
      );
}

/// 계약서 §2-5 `POST /api/session/{id}/end`.
class SessionEnd {
  const SessionEnd({
    required this.sessionId,
    required this.durationSec,
    required this.turnCount,
    required this.summary,
    required this.gapAvg,
  });

  final String sessionId;
  final int durationSec;
  final int turnCount;

  /// **null일 수 있다** — 요약 생성 실패. 요약 영역을 숨긴다 (§1-3).
  final String? summary;

  /// 종료 요약(S02-1)에는 **표시하지 않는다** (design-system §7-7).
  final double? gapAvg;

  factory SessionEnd.fromJson(Map<String, dynamic> j) => SessionEnd(
        sessionId: j['sessionId'] as String,
        durationSec: j['durationSec'] as int,
        turnCount: j['turnCount'] as int,
        summary: j['summary'] as String?,
        gapAvg: (j['gapAvg'] as num?)?.toDouble(),
      );
}

/// `endReason` — 앱은 `timeout`·`resumed`를 보내지 않는다 (§2-5).
abstract final class EndReason {
  static const userEnd = 'user_end';
  static const softWrap = 'soft_wrap';
  static const hardCut = 'hard_cut';
}

/// 계약서 §2-2 `GET /api/me`.
class Me {
  const Me({
    required this.profileId,
    required this.joinedAt,
    required this.sessionCount,
    required this.thresholdMode,
    required this.demoMode,
    this.openSession,
  });

  final String profileId;
  final DateTime joinedAt;
  final int sessionCount;
  final String thresholdMode;
  final bool demoMode;

  /// **비정상 중단으로 열려 있는 세션.** 없으면 null.
  /// null이 아니면 홈에서 "이어서 이야기할까요?"를 제안한다 (F2-07).
  final OpenSession? openSession;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        profileId: j['profileId'] as String,
        joinedAt: DateTime.parse(j['joinedAt'] as String),
        sessionCount: j['sessionCount'] as int,
        thresholdMode: j['thresholdMode'] as String,
        demoMode: j['demoMode'] as bool? ?? false,
        openSession: j['openSession'] == null
            ? null
            : OpenSession.fromJson(j['openSession'] as Map<String, dynamic>),
      );
}

class OpenSession {
  const OpenSession({
    required this.sessionId,
    required this.startedAt,
    required this.usedSec,
    required this.remainingSec,
    required this.resumableUntil,
  });

  final String sessionId;
  final DateTime startedAt;
  final int usedSec;

  /// `hardCutSec − usedSec`.
  final int remainingSec;

  /// 이 시각을 넘기면 스케줄러가 자동 종료한다 (중단 후 30분).
  final DateTime resumableUntil;

  bool get isResumable =>
      remainingSec > 0 && DateTime.now().isBefore(resumableUntil);

  factory OpenSession.fromJson(Map<String, dynamic> j) => OpenSession(
        sessionId: j['sessionId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        usedSec: j['usedSec'] as int,
        remainingSec: j['remainingSec'] as int,
        resumableUntil: DateTime.parse(j['resumableUntil'] as String),
      );
}
