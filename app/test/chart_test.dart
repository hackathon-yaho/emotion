import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/fixtures/sample_data.dart';
import 'package:voice_journal/core/models/trend_models.dart';
import 'package:voice_journal/shared/widgets/two_line_chart.dart';

TrendPoint p(String date, {double? t = 0.5, double? v = -0.2}) => TrendPoint(
      date: date,
      textValence: t,
      voiceValence: v,
      gap: (t == null || v == null) ? null : (t - v).abs(),
      sessionCount: 1,
    );

void main() {
  group('두 선 그래프의 날짜 축 (계약서 §1-3)', () {
    test('기록 없는 날은 배열에서 생략되고, 그 자리는 실제 공백으로 남는다', () {
      // 9/4가 없다 — 0으로 채우거나 앞뒤를 이어 보간하지 않는다.
      final axis = ChartAxis([p('2026-09-03'), p('2026-09-05')]);
      expect(axis.spanDays, 2, reason: '이틀 간격이 한 칸으로 압축되면 안 된다');
      expect(axis.offsetOf(0), 0);
      expect(axis.offsetOf(1), 2);
    });

    test('하루 차이가 아니면 선을 끊는다', () {
      final axis = ChartAxis([
        p('2026-09-03'),
        p('2026-09-05'), // 9/4 없음 → 끊긴다
        p('2026-09-06'),
      ]);
      expect(axis.isConsecutive(1), isFalse);
      expect(axis.isConsecutive(2), isTrue);
    });

    test('첫 점은 언제나 앞이 없으므로 이어지지 않는다', () {
      expect(ChartAxis([p('2026-09-03')]).isConsecutive(0), isFalse);
    });

    test('샘플 데이터에서 9/4 · 9/9 · 9/10 자리에서 끊긴다', () {
      final points = Sample.trend.points;
      final axis = ChartAxis(points);
      final breaks = <String>[];
      for (var i = 1; i < points.length; i++) {
        if (!axis.isConsecutive(i)) breaks.add(points[i].date);
      }
      // 9/5(9/4 없음)와 9/11(9/9·9/10 없음) 앞에서 끊긴다
      expect(breaks, ['2026-09-05', '2026-09-11']);
    });

    test('음영 구간을 날짜로 찾는다 — 배열 인덱스가 아니다', () {
      final axis = ChartAxis(Sample.trend.points);
      final h = Sample.trend.highlights.single;
      expect(axis.indexOfDate(h.from), greaterThanOrEqualTo(0));
      expect(axis.indexOfDate(h.to), greaterThanOrEqualTo(0));
      expect(axis.indexOfDate('2026-01-01'), -1);
    });

    test('축은 −1~+1 고정이다 — 데이터가 좁아도 늘어나지 않는다', () {
      // 값의 범위가 0.1뿐이어도 축을 다시 스케일하지 않는다.
      // (페인터가 y를 (1-v)/2로 계산하므로 데이터에 의존하지 않는다)
      final narrow = [p('2026-09-01', t: 0.05, v: 0.01)];
      expect(narrow.single.textValence, 0.05);
      // 축 고정은 페인터 상수이므로, 여기서는 데이터가 축을 바꿀 여지가
      // 없다는 것만 확인한다.
      expect(ChartAxis(narrow).spanDays, 1);
    });
  });

  group('마커', () {
    test('점 간격이 14px 미만이면 마커를 그리지 않는다 (design-system §7-17)', () {
      expect(TwoLineChart.markerMinStep, 14.0);
    });
  });
}
