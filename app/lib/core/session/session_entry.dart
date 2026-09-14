import '../data/journal_repository.dart';
import '../models/queue_models.dart';
import '../models/session_models.dart';
import 'session_clock.dart';

/// 홈이 「중단된 대화」로 보여줄 세션 — **방금 우리가 닫은 것은 뺀다.**
///
/// 종료 응답을 받은 뒤에 `/me`를 다시 불러도 서버가 그 세션을 아직 열려
/// 있다고 답하는 순간이 있다 (2026-09-14 테스트 — 새로고침하면 사라졌다).
/// 몇 초 뒤의 같은 질문에는 정답이 오므로, **우리가 방금 닫은 id 하나만**
/// 무시한다. 다른 열린 세션은 그대로 보여준다.
OpenSession? visibleOpenSession(OpenSession? fromServer, String? endedId) =>
    fromServer?.sessionId == endedId ? null : fromServer;

/// 「새로 시작」 — **열려 있던 세션을 닫고** 새 세션을 만든다 (계약 §2-5-1).
///
/// 닫지 않으면 그 세션이 이어하기 후보로 남아, 다음 진입에서 화면이 다시
/// `resume`을 부른다. 그러면 사용자가 「새로 시작」을 골랐는데도 대화가
/// 이어지고, 서버의 `durationSec`은 처음 시작한 시각부터 세어진다.
///
/// **닫기에 실패해도 새로 시작한다.** 여기서 멈추면 사용자는 새 대화를 아예
/// 못 하게 되는데, 열린 세션은 서버가 타임아웃으로 정리한다 (§2-6 `timeout`).
Future<SessionStartResult> startFreshSession(
  JournalRepository repo, {
  OpenSession? closing,
}) async {
  if (closing != null) {
    try {
      await repo.endSession(
        closing.sessionId,
        endReason: SessionClock.reasonUserEnd,
      );
    } on Object {
      // 삼킨다 — 위 주석의 이유다.
    }
  }
  return repo.startSession();
}
