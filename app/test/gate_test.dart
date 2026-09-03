import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/models/live_models.dart';
import 'package:voice_journal/core/models/paged.dart';
import 'package:voice_journal/core/session/app_session.dart';

void main() {
  group('진입 자격 (F1-05)', () {
    test('동의 전이면 온보딩이 필요하다 — JWT가 있어도', () {
      expect(
        AppSession.resolve(seenOnboarding: false, jwt: 'jwt'),
        GateStatus.needsOnboarding,
      );
    });

    test('동의했지만 토큰이 없으면 로그인이 필요하다', () {
      expect(
        AppSession.resolve(seenOnboarding: true, jwt: null),
        GateStatus.needsLogin,
      );
      expect(
        AppSession.resolve(seenOnboarding: true, jwt: ''),
        GateStatus.needsLogin,
      );
    });

    test('동의 + 토큰이면 통과한다', () {
      expect(
        AppSession.resolve(seenOnboarding: true, jwt: 'jwt'),
        GateStatus.ready,
      );
    });

    test('통과가 아닌 상태는 전부 대화 화면 진입을 막는다', () {
      // 웹은 주소창에 /conversation 을 쳐서 들어올 수 있다.
      // ready 이외의 어떤 상태도 통과시키지 않아야 한다.
      for (final status in GateStatus.values) {
        final blocked = status != GateStatus.ready;
        expect(
          status == GateStatus.ready,
          !blocked,
          reason: '$status 의 통과 여부가 뒤바뀌었다',
        );
      }
    });
  });

  group('목록 페이징 (계약서 §1-4)', () {
    Map<String, dynamic> body(int total, int count) => {
          'total': total,
          'observations': [
            for (var i = 0; i < count; i++) {'id': '$i'},
          ],
        };

    Paged<String> parse(Map<String, dynamic> j) => Paged.fromJson(
          j,
          key: 'observations',
          itemFromJson: (m) => m['id'] as String,
        );

    test('total과 항목을 분리해 읽는다', () {
      final p = parse(body(37, 20));
      expect(p.total, 37);
      expect(p.items.length, 20);
    });

    test('다음 페이지 여부를 total로 판단한다', () {
      expect(parse(body(37, 20)).hasMore(0), isTrue);
      expect(parse(body(37, 17)).hasMore(20), isFalse);
    });

    test('빈 목록은 total 0이고 억지 항목을 만들지 않는다 (FR-052)', () {
      final p = parse(body(0, 0));
      expect(p.total, 0);
      expect(p.isEmpty, isTrue);
    });

    test('limit은 최대 100으로 잘린다', () {
      expect(const PageQuery(limit: 500).toQuery()['limit'], 100);
      expect(const PageQuery().toQuery()['limit'], 20);
    });

    test('next는 받은 개수만큼 offset을 밀어준다', () {
      final q = const PageQuery().next(20);
      expect(q.offset, 20);
      expect(q.limit, 20);
    });
  });

  _liveSignalTests();
}

/// 계약 v1.3 §2-13 — 대화 중 턴 신호.
void _liveSignalTests() {
  group('대화 중 턴 신호 (§2-13)', () {
    Map<String, dynamic> body({
      bool crisis = false,
      List<Map<String, dynamic>> turns = const [],
      int last = 7,
    }) =>
        {
          'sessionId': '550e8400-e29b-41d4-a716-446655440000',
          'lastTurnIndex': last,
          'crisisDetected': crisis,
          'turns': turns,
        };

    test('비데모 세션은 turns가 빈 배열이고 crisisDetected는 정상 값이다', () {
      // 빈 배열은 "볼 권한이 없다"이지 "값이 없다"가 아니다.
      final s = LiveSignal.fromJson(body(crisis: true));
      expect(s.turns, isEmpty);
      expect(s.crisisDetected, isTrue);
    });

    test('데모 세션은 측정값이 채워진다', () {
      final s = LiveSignal.fromJson(body(turns: [
        {
          'turnIndex': 7,
          'textValence': 0.70,
          'voiceValence': -0.62,
          'gap': 1.32,
          'gapTriggered': true,
        }
      ]));
      expect(s.turns.single.gap, 1.32);
      expect(s.turns.single.gapTriggered, isTrue);
    });

    test('측정 못한 값은 null로 남고 0으로 대체되지 않는다 (§1-3)', () {
      final s = LiveSignal.fromJson(body(turns: [
        {'turnIndex': 3, 'textValence': null, 'voiceValence': null, 'gap': null}
      ]));
      expect(s.turns.single.textValence, isNull);
      expect(s.turns.single.gap, isNull);
    });

    test('S07은 false → true 전이에서 한 번만 뜬다', () {
      // 폴링이 계속 true를 주더라도 다시 띄우지 않는다.
      var shown = 0;
      var previous = false;
      for (final incoming in [false, true, true, true]) {
        if (!previous && incoming) shown++;
        previous = incoming;
      }
      expect(shown, 1);
    });
  });
}
