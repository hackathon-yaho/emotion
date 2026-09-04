import '../fixtures/sample_data.dart';
import '../models/auth_models.dart';
import '../models/live_models.dart';
import '../models/observation_models.dart';
import '../models/paged.dart';
import '../models/record_models.dart';
import '../models/session_models.dart';
import '../models/trend_models.dart';
import 'journal_repository.dart';

/// 네트워크를 타지 않는 구현 — **샘플 모드**.
///
/// 있는 이유는 하나다. **실제 Hume API를 계속 켜 두고 테스트할 수 없다.**
/// EVI는 통화 시간만큼 과금되므로, 화면·흐름을 확인할 때마다 실제 세션을
/// 열면 무료 한도가 개발 중에 사라진다. 이 구현은
///
/// - 백엔드가 없어도 11개 화면이 다 그려지고,
/// - `startSession()`이 **가짜 Hume 토큰**을 주므로 앱은 EVI에 붙지 않고,
/// - `live()`가 **대본대로** 위기 신호와 데모 턴을 만들어 S07·데모 모드를
///   실제 대화 없이 확인할 수 있다.
///
/// **발표 근거로 쓰지 않는다** — PRD §12. 화면 확인·시연 리허설 전용이다.
class SampleJournalRepository implements JournalRepository {
  SampleJournalRepository({this.delay = const Duration(milliseconds: 240)});

  /// 로딩 상태가 실제로 보이도록 한 박자 늦춘다. 0으로 두면 스켈레톤을
  /// 확인할 수 없다.
  final Duration delay;

  /// 샘플 세션이 시작된 시각 — `live()`의 대본 진행에 쓴다.
  DateTime? _startedAt;

  /// 위기 신호를 한 번 준 뒤에는 계속 true다 (실제 서버와 같은 성질).
  bool _crisisFired = false;

  int _turnIndex = 0;

  Future<T> _wait<T>(T value) => Future.delayed(delay, () => value);

  @override
  Future<AuthResult> authKakao({
    required String kakaoAuthCode,
    required String redirectUri,
  }) =>
      _wait(Sample.authResult);

  @override
  Future<Me> me() => _wait(Sample.me);

  @override
  Future<Paged<Observation>> observations({PageQuery? page}) =>
      _wait(_slice(Sample.observations, page ?? const PageQuery()));

  @override
  Future<ObservationEvidence> evidence(String observationId) =>
      _wait(Sample.evidenceDetail);

  @override
  Future<FeedbackResult> sendFeedback(
    String observationId, {
    required bool agree,
  }) =>
      _wait(FeedbackResult(
        observationId: observationId,
        feedback: agree ? 'agree' : 'disagree',
      ));

  @override
  Future<Trend> trend(String range) => _wait(Sample.trendOf(range));

  @override
  Future<Paged<SessionSummary>> sessions({PageQuery? page}) =>
      _wait(_slice(Sample.sessions, page ?? const PageQuery()));

  @override
  Future<SessionDetail> session(String sessionId) => _wait(Sample.sessionDetail);

  @override
  Future<SessionDeleteResult> deleteSession(String sessionId) => _wait(
        SessionDeleteResult(
          deletedSessionId: sessionId,
          deletedTurnCount: Sample.sessionDetail.turns.length,
          removedObservationIds: const [],
          recalculatedObservationIds: const [],
        ),
      );

  @override
  Future<SessionStart> startSession() {
    _startedAt = DateTime.now();
    _crisisFired = false;
    _turnIndex = 0;
    return _wait(Sample.sessionStart);
  }

  @override
  Future<SessionResume> resumeSession(String sessionId) {
    _startedAt = DateTime.now();
    return _wait(Sample.sessionResume);
  }

  @override
  Future<SessionEnd> endSession(String sessionId, {required String endReason}) {
    _startedAt = null;
    final s = Sample.sessions.first;
    return _wait(SessionEnd(
      sessionId: sessionId,
      durationSec: s.durationSec,
      turnCount: s.turnCount,
      summary: s.summary,
      gapAvg: s.gapAvg,
    ));
  }

  /// 대본 — 세션 시작 후 **12초가 지나면** 위기 신호를 한 번 올린다.
  ///
  /// 시연 리허설에서 S07을 보려면 실제로 위기 발화를 해야 하는데, 그건
  /// 사람에게도 서버에도 좋은 방법이 아니다. 시간으로 대신한다.
  @override
  Future<LiveSignal> live(String sessionId) {
    const crisisAfter = Duration(seconds: 12);
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    if (elapsed >= crisisAfter) _crisisFired = true;
    _turnIndex++;

    return _wait(LiveSignal(
      sessionId: sessionId,
      lastTurnIndex: _turnIndex,
      crisisDetected: _crisisFired,
      // 데모 모드에서만 채워지는 자리다. 샘플에서는 항상 채워 화면을
      // 확인할 수 있게 한다.
      turns: [Sample.liveTurn(_turnIndex)],
    ));
  }

  @override
  Future<void> deleteAccount({String? kakaoAuthCode, String? redirectUri}) =>
      Future.delayed(delay);

  Paged<T> _slice<T>(List<T> all, PageQuery page) {
    final from = page.offset.clamp(0, all.length);
    final to = (page.offset + page.limit).clamp(0, all.length);
    return Paged(total: all.length, items: all.sublist(from, to));
  }
}
