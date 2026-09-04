import 'package:flutter/material.dart';

import '../../core/models/trend_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 이야기별 갭 막대.
///
/// **세로 실선 = 내 평균, 점선 = ×1.5.** 둘을 넘고 세 번 이상 나오면 발견이
/// 된다(FR-051). 조건을 넘은 막대만 밝게 — **코드의 판정 기준을 그대로 보여주는
/// 것**이며 좋음/나쁨 색이 아니다.
///
/// 갭은 채널이 아니므로 `cool`/`warm`을 쓰지 않는다 (design-system §7-16).
///
/// 데이터는 `GET /api/trend`의 `tagGaps`·`userAvgGap`으로 온다 (계약 v1.4 §2-8).
class TagGapBars extends StatelessWidget {
  const TagGapBars({
    super.key,
    required this.rows,
    required this.userAvgGap,
    this.labelWidth = 96,
    this.valueWidth = 40,
    this.rowGap = Space.lg,
  });

  final List<TagGap> rows;

  /// 개인 전체 평균 갭 — 막대의 기준선.
  final double userAvgGap;

  final double labelWidth;
  final double valueWidth;
  final double rowGap;

  /// 관찰 생성 배수 (FR-051).
  static const ratioThreshold = 1.5;

  /// 관찰 생성 최소 등장 횟수 (FR-051).
  static const minOccurrences = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (rows.isEmpty) return const SizedBox.shrink();

    final threshold = userAvgGap * ratioThreshold;
    final maxV = [
      threshold,
      ...rows.map((r) => r.tagAvgGap),
    ].reduce((a, b) => a > b ? a : b) * 1.12;

    return LayoutBuilder(
      builder: (context, c) {
        const gap = Space.md;
        final plotW = c.maxWidth - labelWidth - gap * 2 - valueWidth;
        double barW(double v) => (v / maxV) * plotW;
        double lineLeft(double v) => labelWidth + gap + barW(v);

        return Stack(
          children: [
            // 기준선 — 내 평균(실선)과 ×1.5(점선)
            Positioned(
              left: lineLeft(userAvgGap),
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: t.line),
            ),
            Positioned(
              left: lineLeft(threshold),
              top: 0,
              bottom: 0,
              child: CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLine(t.faint),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) SizedBox(height: rowGap),
                  _row(context, rows[i], barW, threshold),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    TagGap r,
    double Function(double) barW,
    double threshold,
  ) {
    final t = context.tokens;
    final hit = r.occurrences >= minOccurrences && r.tagAvgGap >= threshold;
    final ink = hit ? t.paper : t.faint;

    return SizedBox(
      height: 18,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              '${r.tag} · ${r.occurrences}회',
              style: AppType.sans(
                size: AppType.captionSize,
                color: t.muted,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: barW(r.tagAvgGap),
                height: 6,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: const BorderRadius.all(Radii.control),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          SizedBox(
            width: valueWidth,
            child: Text(
              r.tagAvgGap.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: AppType.sans(
                size: AppType.labelSize,
                color: ink,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  _DashedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 2.0;
    const space = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + space;
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
