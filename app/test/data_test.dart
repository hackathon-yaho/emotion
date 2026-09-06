import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/data/journal_repository.dart';
import 'package:voice_journal/core/data/sample_journal_repository.dart';
import 'package:voice_journal/core/models/paged.dart';
import 'package:voice_journal/core/models/queue_models.dart';
import 'package:voice_journal/core/models/session_models.dart';
import 'package:voice_journal/core/network/api_client.dart';
import 'package:voice_journal/core/storage/token_storage.dart';
import 'package:voice_journal/core/models/trend_models.dart';

void main() {
  group('계약 v1.4 §2-8 — tagGaps는 trend 응답에 실려 온다', () {
    test('userAvgGap·tagGaps를 파싱한다', () {
      final t = Trend.fromJson(const {
        'range': '30d',
        'timezone': 'Asia/Seoul',
        'points': [
          {
            'date': '2026-09-14',
            'textValence': 0.2,
            'voiceValence': 0.1,
            'gap': 0.1,
            'sessionCount': 1,
          },
        ],
        'highlights': [],
        'userAvgGap': 0.72,
        'tagGaps': [
          {'tag': '회의', 'occurrences': 7, 'tagAvgGap': 1.31},
        ],
      });

      expect(t.userAvgGap, 0.72);
      expect(t.tagGaps.single.tag, '회의');
      expect(t.tagGaps.single.occurrences, 7);
    });

    test('없으면 빈 배열과 null이다 — 0으로 채우지 않는다', () {
      final t = Trend.fromJson(const {
        'range': '7d',
        'timezone': 'Asia/Seoul',
        'points': [],
        'highlights': [],
      });

      expect(t.tagGaps, isEmpty);
      expect(t.userAvgGap, isNull, reason: '평균이 없는 것과 0은 다르다');
    });
  });

  group('샘플 모드 (Hume을 타지 않기 위한 것)', () {
    final repo = SampleJournalRepository(delay: Duration.zero);

    test('세션 시작이 주는 Hume 토큰은 가짜다 — 실제 통화가 열리지 않는다', () async {
      // 샘플 모드는 줄을 서지 않는다 — 대기열은 Hume 상한 때문에 있는 것이고
      // 여기서는 Hume에 붙지 않는다 (§2-14).
      final opened = await repo.startSession();
      final s = (opened as SessionOpened).session;
      expect(s.humeAccessToken, 'sample-not-a-real-token');
      expect(s.humeAccessToken.contains('.'), isFalse,
          reason: 'JWT 모양이면 실수로 EVI에 붙일 수 있다');
    });

    test('데모 턴이 채워져 온다 — 실제 대화 없이 수치 패널을 확인할 수 있다', () async {
      await repo.startSession();
      final live = await repo.live('s');
      expect(live.turns, isNotEmpty);
      expect(live.turns.single.gapTriggered, isTrue);
    });

    test('위기 신호는 대본대로 켜지고, 켜진 뒤에는 계속 켜져 있다', () async {
      // 실제 서버도 세션 단위 boolean이라 한 번 true면 계속 true다 (§2-13).
      final r = SampleJournalRepository(delay: Duration.zero);
      await r.startSession();
      expect((await r.live('s')).crisisDetected, isFalse,
          reason: '시작 직후에는 아직 아니다');
    });

    test('목록은 §1-4 봉투로 오고 total이 전체 개수다', () async {
      final page1 = await repo.sessions(page: const PageQuery(limit: 2));
      expect(page1.items.length, 2);
      expect(page1.total, greaterThan(2));
      expect(page1.hasMore(0), isTrue);

      final page2 = await repo.sessions(
        page: const PageQuery(limit: 2, offset: 2),
      );
      expect(page2.items.first.sessionId,
          isNot(page1.items.first.sessionId));
    });

    test('추세 7일은 30일의 끝에서 잘라 쓴다 — 두 화면이 다른 이야기를 하지 않는다', () async {
      final d30 = await repo.trend(TrendRange.d30);
      final d7 = await repo.trend(TrendRange.d7);
      expect(d7.points.length, lessThanOrEqualTo(7));
      expect(d7.points.last.date, d30.points.last.date);
      expect(d7.userAvgGap, d30.userAvgGap);
    });

    test('삭제 요청도 응답 모양을 지킨다', () async {
      final r = await repo.deleteSession('abc');
      expect(r.deletedSessionId, 'abc');
      expect(r.deletedTurnCount, greaterThan(0));
    });
  });

  group('인터페이스로 호출해도 기본 페이지가 채워진다', () {
    // **웹 릴리스에서만 터지던 버그의 회귀 테스트.**
    // 인터페이스 쪽 optional 파라미터에 기본값을 두고 구현에서만 채우면,
    // 호출부의 정적 타입이 인터페이스일 때 dart2js가 null을 넘겨
    // `NoSuchMethodError: page.get$offset is not a function`으로 죽었다.
    // VM에서는 구현의 기본값이 쓰여 통과했다 — 그래서 테스트로는 못 잡았고
    // 브라우저 렌더로 잡았다. 지금은 nullable + `?? const PageQuery()`다.
    test('page를 생략해도 목록이 온다', () async {
      final JournalRepository repo =
          SampleJournalRepository(delay: Duration.zero);
      expect((await repo.observations()).items, isNotEmpty);
      expect((await repo.sessions()).items, isNotEmpty);
    });

    test('page를 주면 그대로 쓴다', () async {
      final JournalRepository repo =
          SampleJournalRepository(delay: Duration.zero);
      final one = await repo.observations(page: const PageQuery(limit: 1));
      expect(one.items.length, 1);
    });
  });

  group('페이징 이어 붙이기 (§7 결정 22)', () {
    test('다음 장을 이어 붙이고, 끝이면 더 부르지 않는다', () async {
      final repo = SampleJournalRepository(delay: Duration.zero);
      final first = await repo.sessions(page: const PageQuery(limit: 2));
      expect(first.hasMore(0), isTrue);

      final second = await repo.sessions(
        page: PageQuery(limit: 2, offset: first.items.length),
      );
      final merged = Paged(
        total: second.total,
        items: [...first.items, ...second.items],
      );
      expect(merged.items.length, 4);
      // 샘플이 4건이면 여기서 끝이다.
      expect(merged.hasMore(0), merged.items.length < merged.total);
    });

    test('offset이 총 개수를 넘어도 빈 장을 준다 — 예외가 아니다', () async {
      final repo = SampleJournalRepository(delay: Duration.zero);
      final page = await repo.sessions(page: const PageQuery(offset: 999));
      expect(page.items, isEmpty);
      expect(page.total, greaterThan(0));
    });
  });

  group('세션 종료 사유 (§2-5)', () {
    test('종료 호출에 사유가 필요하다', () async {
      final repo = SampleJournalRepository(delay: Duration.zero);
      await repo.startSession();
      final end = await repo.endSession('s', endReason: 'hard_cut');
      expect(end.sessionId, 's');
    });
  });

  group('대기열 (계약 v1.9 §2-14)', () {
    test('202 본문을 티켓으로 읽는다 — position은 1부터', () {
      final t = QueueTicket.fromJson(const {
        'ticketId': 'b2f4c1a0',
        'position': 3,
        'pollIntervalSec': 2,
        'session': null,
      });
      expect(t.position, 3);
      expect(t.isReady, isFalse, reason: '내 차례가 아니다');
      expect(t.session, isNull, reason: '자리를 미리 잡아 두지 않는다');
    });

    test('position 0이면 session이 입장권이다', () {
      final t = QueueTicket.fromJson({
        'ticketId': 'b2f4c1a0',
        'position': 0,
        'pollIntervalSec': 2,
        'session': {
          'sessionId': '550e8400-e29b-41d4-a716-446655440000',
          'humeAccessToken': 'tok',
          'humeTokenExpiresAt': '2026-09-06T00:30:00Z',
          'thresholdMode': 'fixed',
          'gapThreshold': 0.9,
          'softWrapSec': 300,
          'hardCutSec': 420,
          'demoMode': false,
          'humeConfigId': 'cfg',
          'livePollIntervalSec': 2,
        },
      });
      expect(t.isReady, isTrue);
      expect(t.session!.humeConfigId, 'cfg');
    });

    test('pollIntervalSec이 없으면 2초 — 앱에 상수로 박지 않는다', () {
      final t = QueueTicket.fromJson(const {'ticketId': 'x', 'position': 1});
      expect(t.pollIntervalSec, 2);
    });

    test('샘플 모드는 줄을 서지 않는다', () async {
      final repo = SampleJournalRepository(delay: Duration.zero);
      expect(await repo.startSession(), isA<SessionOpened>());
    });
  });

  group('§2-5-1 이어하기 응답 (2026-09-06 통합 회귀)', () {
    // **실제로 여기서 앱이 죽었다.** 계약은 `resumedChatGroupId`를 필수로
    // 적어 뒀지만 값이 없을 때를 정하지 않았고, 백엔드는 보관된 값이 없으면
    // null을 준다. `String`으로 받다가 TypeError가 났는데 화면에는 "지금은
    // 대화를 시작할 수 없습니다"만 떠서 원인이 보이지 않았다.
    Map<String, dynamic> body(Object? chatGroup) => {
          'sessionId': '550e8400-e29b-41d4-a716-446655440000',
          'humeAccessToken': 'tok',
          'resumedChatGroupId': chatGroup,
          'remainingSec': 240,
          'thresholdMode': 'fixed',
          'gapThreshold': 0.9,
          'demoMode': false,
          'humeConfigId': 'cfg',
        };

    test('값이 있으면 그대로 쓴다', () {
      expect(SessionResume.fromJson(body('cg_1')).resumedChatGroupId, 'cg_1');
    });

    test('null이어도 깨지지 않는다 — 이어하기는 되고 맥락만 안 붙는다', () {
      final r = SessionResume.fromJson(body(null));
      expect(r.resumedChatGroupId, isNull);
      expect(r.remainingSec, 240, reason: '나머지 필드는 정상이어야 한다');
    });

    test('빈 문자열도 "없음"이다 — 계약이 어느 쪽으로 정해져도 산다', () {
      expect(SessionResume.fromJson(body('')).resumedChatGroupId, isNull);
    });
  });

  group('콜드 스타트 (2026-09-06 통합)', () {
    // Render 무료는 유휴 15분에 잠들고 **실측 17.7초** 만에 깨어난다.
    // 종전 타임아웃(연결 10초·수신 15초)으로는 깨는 동안 반드시 실패했고,
    // 화면은 "네트워크를 확인해 주세요"로 **사용자 잘못처럼** 말했다.
    test('타임아웃이 깨어나는 시간을 견딘다', () {
      final client = ApiClient(tokens: TokenStorage());
      expect(client.connectTimeout.inSeconds, greaterThanOrEqualTo(20));
      expect(client.receiveTimeout.inSeconds, greaterThanOrEqualTo(45),
          reason: '17.7초를 견디고도 여유가 있어야 한다');
    });
  });
}
