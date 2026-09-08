import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/data/journal_repository.dart';
import 'package:voice_journal/core/models/queue_models.dart';
import 'package:voice_journal/core/models/session_models.dart';
import 'package:voice_journal/core/session/session_entry.dart';

/// 홈의 「새로 시작」이 **이어하기와 같은 동작**이었다 (2026-09-08 실사용).
///
/// 두 버튼이 같은 경로로 대화 화면을 열고, 화면은 열린 세션이 있으면 무조건
/// `resume`을 불렀다. 사용자에게는 "새로 시작을 골랐는데 대화 시간이 10분"으로
/// 보였다 — 이어한 세션의 경과 시간이었다. 계약 §2-5-1은 이 경우 그 세션을
/// `end`로 닫으라고 정한다.
void main() {
  final open = OpenSession(
    sessionId: 'old-session',
    startedAt: DateTime.utc(2026, 9, 8, 10),
    usedSec: 120,
    remainingSec: 300,
    resumableUntil: DateTime.utc(2026, 9, 8, 10, 32),
  );

  test('열린 세션을 닫고 나서 새로 시작한다 — 순서가 중요하다', () async {
    final repo = _FakeRepo();
    final result = await startFreshSession(repo, closing: open);
    expect(repo.calls, ['end:old-session:user_end', 'start']);
    expect(result, isA<SessionOpened>());
  });

  test('닫을 것이 없으면 그냥 시작한다', () async {
    final repo = _FakeRepo();
    await startFreshSession(repo);
    expect(repo.calls, ['start']);
  });

  test('닫기가 실패해도 새로 시작한다 — 여기서 멈추면 대화를 못 한다', () async {
    final repo = _FakeRepo(failEnd: true);
    final result = await startFreshSession(repo, closing: open);
    expect(repo.calls, ['end:old-session:user_end', 'start']);
    expect(result, isA<SessionOpened>());
  });

  test('정원이 차면 대기열 결과를 그대로 넘긴다', () async {
    final repo = _FakeRepo(queued: true);
    final result = await startFreshSession(repo, closing: open);
    expect(result, isA<SessionQueued>());
    expect(repo.calls.first, 'end:old-session:user_end',
        reason: '줄을 서더라도 옛 세션은 닫는다');
  });
}

class _FakeRepo implements JournalRepository {
  _FakeRepo({this.failEnd = false, this.queued = false});

  final bool failEnd;
  final bool queued;
  final calls = <String>[];

  @override
  Future<SessionEnd> endSession(String id, {required String endReason}) async {
    calls.add('end:$id:$endReason');
    if (failEnd) throw Exception('boom');
    return SessionEnd(
      sessionId: id,
      durationSec: 120,
      turnCount: 4,
      summary: null,
      gapAvg: null,
    );
  }

  @override
  Future<SessionStartResult> startSession() async {
    calls.add('start');
    if (queued) {
      return SessionQueued(QueueTicket(
        ticketId: 't1',
        position: 2,
        pollIntervalSec: 2,
      ));
    }
    return SessionOpened(SessionStart(
      sessionId: 'new-session',
      humeAccessToken: 'tok',
      humeTokenExpiresAt: DateTime.utc(2026, 9, 8, 11),
      thresholdMode: 'fixed',
      gapThreshold: 0.85,
      softWrapSec: 300,
      hardCutSec: 420,
      demoMode: false,
      humeConfigId: 'cfg',
      livePollIntervalSec: 2,
    ));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
