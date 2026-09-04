import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/data/journal_repository.dart';
import 'package:voice_journal/core/data/sample_journal_repository.dart';
import 'package:voice_journal/core/models/paged.dart';
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
      final s = await repo.startSession();
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
}
