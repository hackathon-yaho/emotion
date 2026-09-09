import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/models/record_models.dart';

/// 말이 한 번도 오가지 않은 세션은 기록에 보이지 않는다.
///
/// 백엔드가 `durationSec` 정의를 고치며(계약 v1.11) **턴 0건 세션도 계속
/// 내려주고 보일지 말지는 앱이 정하라**고 넘겼다
/// (`response/app/duration-definition.md`). 감추기로 했다 — 기록은 돌아볼
/// 것이 있는 대화의 목록이고, 빈 줄은 「요약이 없습니다 · 0초」로만 보인다.
void main() {
  SessionSummary make({required int turnCount, String? summary}) =>
      SessionSummary(
        sessionId: 's',
        startedAt: DateTime.utc(2026, 9, 9),
        durationSec: turnCount == 0 ? 0 : 31,
        turnCount: turnCount,
        summary: summary,
        gapAvg: null,
        tags: const [],
      );

  test('턴 0건이면 빈 세션이다', () {
    expect(make(turnCount: 0).isEmpty, isTrue);
  });

  test('한 턴이라도 있으면 보여준다 — 요약이 없어도', () {
    // 요약 생성은 실패할 수 있다(§2-5). 그건 감출 이유가 아니다.
    expect(make(turnCount: 1).isEmpty, isFalse);
    expect(make(turnCount: 4, summary: null).isEmpty, isFalse);
  });

  test('서버가 준 계약 모양을 그대로 판정한다', () {
    final s = SessionSummary.fromJson({
      'sessionId': '96b036cc',
      'startedAt': '2026-09-08T06:51:44Z',
      'durationSec': 0,
      'turnCount': 0,
      'summary': null,
      'gapAvg': null,
    });
    expect(s.isEmpty, isTrue);
  });
}
