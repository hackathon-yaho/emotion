import 'package:flutter/material.dart';

import '../../core/models/trend_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 두 선 그래프 — 이 제품의 서명 화면 (F9-01).
///
/// | 규칙 | 근거 |
/// | --- | --- |
/// | 축은 **−1 ~ +1 고정** | F9-01 수용 기준. 데이터에 따라 축을 늘리지 않는다 |
/// | 축은 **하나** | 두 계열이 같은 척도다. 이중 축을 쓰지 않는다 |
/// | 기록이 없는 날은 **선을 끊는다** | 계약서 §1-3 |
/// | x는 **날짜 기준** | 없는 날은 배열에서 생략되므로(§1-3) 배열 순서로 놓으면 시간이 압축되고 선이 이어져 버린다 |
/// | 갭 구간 음영은 **중립 회색** | 색으로 좋음/나쁨을 말하지 않는다 |
/// | 마커는 점 간격이 **14px 이상일 때만** | 90일에서는 겹친다 (design-system §7-17) |
/// 기간의 날짜 축을 계산한다.
///
/// **계약서 §1-3: 기록이 없는 날은 `points`에서 생략된다.** 그래서 배열
/// 순서로 x를 놓으면 3일 공백이 1칸으로 압축되고 선이 이어져 버린다 —
/// 보간하지 않는다는 규칙이 화면에서 깨진다. 날짜를 기준으로 놓는다.
class ChartAxis {
  ChartAxis(this.points)
      : _days = points.map(_dayIndex).toList(growable: false);

  final List<TrendPoint> points;
  final List<int> _days;

  /// 첫 날부터 마지막 날까지의 총 일수 − 1 (칸 수).
  int get spanDays =>
      _days.isEmpty ? 0 : (_days.last - _days.first).clamp(1, 1 << 30);

  /// i번째 점이 첫 날에서 며칠 뒤인지.
  int offsetOf(int i) => _days[i] - _days.first;

  /// 앞 점과 **하루 차이**인지. 아니면 선을 끊는다.
  bool isConsecutive(int i) => i > 0 && _days[i] - _days[i - 1] == 1;

  int indexOfDate(String date) => points.indexWhere((p) => p.date == date);

  /// 점이 촘촘할 때도 마커를 남길 날인지 — **양 끝과 음영 구간의 경계·내부**.
  ///
  /// "언제 벌어졌는지"가 점으로 보여야 한다는 게 이 화면의 목적이므로,
  /// 지울 수 없는 것은 그 구간과 기간의 시작·끝이다.
  bool isKeyPoint(int i, List<TrendHighlight> highlights) {
    if (points.isEmpty) return false;
    if (i == 0 || i == points.length - 1) return true;
    final day = _days[i];
    for (final h in highlights) {
      final from = indexOfDate(h.from);
      final to = indexOfDate(h.to);
      if (from < 0 || to < 0) continue;
      if (day >= _days[from] && day <= _days[to]) return true;
    }
    return false;
  }

  static int _dayIndex(TrendPoint p) {
    final d = DateTime.tryParse(p.date);
    if (d == null) return 0;
    return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }
}

class TwoLineChart extends StatelessWidget {
  const TwoLineChart({
    super.key,
    required this.points,
    required this.highlights,
    this.height = 188,
    this.leftGutter = 24,
    this.onHighlightTap,
  });

  final List<TrendPoint> points;
  final List<TrendHighlight> highlights;
  final double height;

  /// 축 라벨(+1 · 0 · −1) 자리.
  final double leftGutter;

  /// 음영 구간을 누르면 그날의 대화로 (F9-02).
  final VoidCallback? onHighlightTap;

  /// 마커를 그릴 최소 점 간격.
  /// 하루당 폭이 이보다 좁으면 **모든 날에** 점을 찍지 않는다 — 점이 붙어
  /// 뭉개지면 선이 오히려 안 보인다.
  ///
  /// 좁을 때 점을 통째로 없애지는 않는다. 아래 [ChartAxis.isKeyPoint]가 고른
  /// **양 끝과 음영 구간의 날**에만 찍는다. 30일·90일은 **어느 폭에서도**
  /// 이 임계를 못 넘기고(폰 390에서 30일이 11px), 모바일은 넓힐 수가 없다 —
  /// 그래서 밀도는 폭이 아니라 여기서 푼다 (design-system §2-1).
  static const markerMinStep = 14.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        return GestureDetector(
          onTap: onHighlightTap,
          child: CustomPaint(
            size: Size(width, height),
            painter: _ChartPainter(
              points: points,
              axis: ChartAxis(points),
              highlights: highlights,
              leftGutter: leftGutter,
              cool: t.cool,
              warm: t.warm,
              line: t.line,
              shade: t.shade,
              faint: t.faint,
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.axis,
    required this.highlights,
    required this.leftGutter,
    required this.cool,
    required this.warm,
    required this.line,
    required this.shade,
    required this.faint,
  });

  final List<TrendPoint> points;
  final ChartAxis axis;
  final List<TrendHighlight> highlights;
  final double leftGutter;
  final Color cool;
  final Color warm;
  final Color line;
  final Color shade;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final plotH = size.height - top * 2;
    final plotW = size.width - leftGutter;
    final span = axis.spanDays;
    final dayW = span > 0 ? plotW / span : 0.0;

    // x는 날짜 기준 — 없는 날은 실제 공백으로 남는다.
    double x(int i) => leftGutter + axis.offsetOf(i) * dayW;
    double y(double v) => top + ((1 - v) / 2) * plotH;

    // 갭 구간 음영 — 경계는 점 중심이 아니라 반 보폭 밖에 둔다.
    final shadePaint = Paint()..color = shade;
    for (final h in highlights) {
      final from = axis.indexOfDate(h.from);
      final to = axis.indexOfDate(h.to);
      if (from < 0 || to < 0) continue;
      canvas.drawRect(
        Rect.fromLTRB(
          x(from) - dayW / 2,
          top,
          x(to) + dayW / 2,
          top + plotH,
        ),
        shadePaint,
      );
    }

    // 0선과 ±1 파선
    final zeroLine = Paint()
      ..color = line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftGutter, y(0)),
      Offset(size.width, y(0)),
      zeroLine,
    );

    // 계열 — null인 날에서 선을 끊는다
    final dense = dayW < TwoLineChart.markerMinStep;
    _drawSeries(canvas, (p) => p.textValence, x, y, cool, dense);
    _drawSeries(canvas, (p) => p.voiceValence, x, y, warm, dense);

    // 축 라벨
    _label(canvas, '+1', Offset(0, y(1) - 6));
    _label(canvas, '0', Offset(4, y(0) - 6));
    _label(canvas, '−1', Offset(0, y(-1) - 6));
  }

  void _drawSeries(
    Canvas canvas,
    double? Function(TrendPoint) pick,
    double Function(int) x,
    double Function(double) y,
    Color color,
    bool dense,
  ) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = color;
    // 촘촘하면 점을 다 찍지 않고 골라 찍는다. 반지름도 한 단계 줄인다.
    final radius = dense ? 3.0 : 4.0;

    var run = <Offset>[];
    void flush() {
      if (run.length > 1) {
        final path = Path()..moveTo(run.first.dx, run.first.dy);
        for (final o in run.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, stroke);
      }
      run = <Offset>[];
    }

    for (var i = 0; i < points.length; i++) {
      final v = pick(points[i]);
      if (v == null) {
        flush();
        continue;
      }
      // 앞 점과 하루 차이가 아니면 — 사이에 기록 없는 날이 있으면 — 끊는다.
      if (i > 0 && !axis.isConsecutive(i)) flush();
      final o = Offset(x(i), y(v));
      run.add(o);
      // 조각이 1점이라 선이 안 그려지더라도 마커는 남긴다 — 하루만 있는 날이
      // 통째로 사라지지 않게.
      if (!dense || axis.isKeyPoint(i, highlights)) {
        canvas.drawCircle(o, radius, dot);
      }
    }
    flush();
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppType.sans(
          size: AppType.labelSize,
          color: faint,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.highlights != highlights;
}

/// x축 날짜 라벨 — 8개 안팎으로 간격을 두고, 끝 날짜는 항상 넣는다.
class ChartDateAxis extends StatelessWidget {
  const ChartDateAxis({
    super.key,
    required this.points,
    this.leftGutter = 24,
    this.maxLabels = 8,
  });

  final List<TrendPoint> points;
  final double leftGutter;
  final int maxLabels;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (points.length < 2) return const SizedBox(height: 18);

    final every = (points.length / maxLabels).ceil().clamp(1, points.length);
    final picks = <int>[];
    for (var i = 0; i < points.length; i += every) {
      picks.add(i);
    }
    if (picks.last != points.length - 1) picks.add(points.length - 1);

    final axis = ChartAxis(points);

    return LayoutBuilder(
      builder: (context, c) {
        final plotW = c.maxWidth - leftGutter;
        final dayW = plotW / axis.spanDays;
        const labelW = 52.0;
        // 끝 라벨이 잘리지 않게 좌우로 클램프한다.
        double left(int i) => (leftGutter + axis.offsetOf(i) * dayW - labelW / 2)
            .clamp(0.0, c.maxWidth - labelW);
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              for (final i in picks)
                Positioned(
                  left: left(i),
                  width: labelW,
                  child: Text(
                    _short(points[i].date),
                    textAlign: TextAlign.center,
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.faint,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// `2026-09-12` → `9/12`
  static String _short(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }
}

/// 두 계열 범례. **2계열이므로 항상 표시한다** — 색만으로 구분되게 두지 않는다.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, this.showShade = false});

  final bool showShade;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        _item(context, t.cool, '말한 내용', 2),
        const SizedBox(width: Space.xl - 2),
        _item(context, t.warm, '목소리', 2),
        if (showShade) ...[
          const SizedBox(width: Space.xl - 2),
          _item(context, t.shade, '두 선이 벌어진 구간', 8),
        ],
      ],
    );
  }

  Widget _item(BuildContext context, Color color, String label, double h) {
    final t = context.tokens;
    return Row(
      children: [
        Container(width: 14, height: h, color: color),
        const SizedBox(width: Space.sm),
        Text(
          label,
          style: AppType.sans(
            size: AppType.captionSize,
            color: t.muted,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
