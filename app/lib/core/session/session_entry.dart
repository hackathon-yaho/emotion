import '../data/journal_repository.dart';
import '../models/queue_models.dart';
import '../models/session_models.dart';
import 'session_clock.dart';

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
