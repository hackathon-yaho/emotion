import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/models/session_models.dart';
import 'package:voice_journal/core/session/session_clock.dart';

/// 홈의 이어하기 카드와 이어하기 링에 **시안 숫자가 상수로 박혀** 있었다
/// (2026-09-07). "5분 전에 중단된 대화", "남은 시간 4분 42초 · 원래 7분" —
/// 언제 중단했든 얼마가 남았든 늘 같은 문장이었다. 서버 값으로 만든다.
void main() {
  group('SessionClock.spell', () {
    test('분·초를 사람 말로 옮긴다', () {
      expect(SessionClock.spell(282), '4분 42초');
      expect(SessionClock.spell(420), '7분');
      expect(SessionClock.spell(59), '59초');
      expect(SessionClock.spell(60), '1분');
      expect(SessionClock.spell(3600), '1시간');
      expect(SessionClock.spell(3720), '1시간 2분');
    });

    test('음수는 0초다 — 남은 시간이 음수라고 적지 않는다', () {
      expect(SessionClock.spell(-5), '0초');
    });
  });

  group('SessionClock.ago', () {
    final now = DateTime.utc(2026, 9, 7, 12, 0);
    test('경과에 따라 단위를 바꾼다', () {
      expect(SessionClock.ago(now.subtract(const Duration(seconds: 20)), now: now),
          '방금 전');
      expect(SessionClock.ago(now.subtract(const Duration(minutes: 5)), now: now),
          '5분 전');
      expect(SessionClock.ago(now.subtract(const Duration(hours: 2)), now: now),
          '2시간 전');
      expect(SessionClock.ago(now.subtract(const Duration(days: 3)), now: now),
          '3일 전');
    });

    test('기기 시계가 앞서 미래 시각이 와도 "방금 전"이다', () {
      expect(SessionClock.ago(now.add(const Duration(minutes: 3)), now: now),
          '방금 전');
    });
  });

  group('OpenSession 파생값', () {
    final open = OpenSession.fromJson({
      'sessionId': 's1',
      'startedAt': '2026-09-07T11:50:00Z',
      'usedSec': 138,
      'remainingSec': 282,
      'resumableUntil': '2026-09-07T12:22:18Z',
    });

    test('중단 시각은 시작 + 쓴 시간이다', () {
      expect(open.stoppedAt, DateTime.utc(2026, 9, 7, 11, 52, 18));
    });

    test('원래 주어진 시간은 쓴 시간 + 남은 시간이다', () {
      expect(open.totalSec, 420);
      expect(SessionClock.spell(open.totalSec), '7분');
      expect(SessionClock.spell(open.remainingSec), '4분 42초');
    });
  });
}
