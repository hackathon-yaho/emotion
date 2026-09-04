import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fixtures/sample_data.dart';
import '../../core/models/trend_models.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/doubled_text.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';
import '../../shared/widgets/tag_gap_bars.dart';
import '../../shared/widgets/two_line_chart.dart';

/// S04 추세.
///
/// F9-01 두 선 그래프 · F9-02 갭 구간 강조 · F9-03 이야기별 갭(P1).
///
/// 제목에 **「두 겹」**을 쓴다 — 그래프의 두 선이 이미 두 겹이라 제목이 그것을
/// 예고한다 (design-system §1).
class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key, this.isEmpty = false, this.isLoading = false});

  final bool isEmpty;
  final bool isLoading;

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  String _range = TrendRange.d30;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final trend = Sample.trend;

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('추세'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 36, bottom: Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DoubledText('말한 내용과 목소리'),
                  const SizedBox(height: Space.xl),
                  _RangePicker(
                    current: _range,
                    onPick: (r) => setState(() => _range = r),
                  ),
                  const SizedBox(height: Space.xl),

                  if (widget.isLoading)
                    const SkeletonLines(widths: [1, 1, 1, 1], gap: 50)
                  else if (widget.isEmpty)
                    const EmptyState(
                      message:
                          '아직 그릴 기록이 없습니다.\n대화가 쌓이면 말한 내용과 목소리를 나란히 보여드립니다.',
                    )
                  else ...[
                    TwoLineChart(
                      points: trend.points,
                      highlights: trend.highlights,
                      onHighlightTap: () => context.push(
                        Routes.recordDetailOf(Sample.sessions.first.sessionId),
                      ),
                    ),
                    ChartDateAxis(points: trend.points),
                    const SizedBox(height: Space.xl),
                    const ChartLegend(showShade: true),
                    const SizedBox(height: Space.lg),
                    Text(
                      '음영 구간에서 두 선이 가장 크게 벌어졌습니다. 눌러서 그날 대화를 볼 수 있습니다.',
                      style: AppType.sans(
                        size: AppType.captionSize,
                        color: t.faint,
                        height: 1.7,
                      ),
                    ),

                    const SizedBox(height: Space.xxl),
                    const Hairline(),
                    const SizedBox(height: Space.xl),
                    const _TagGapSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// F9-03 이야기별 갭.
///
/// 데이터 경로가 계약에 아직 없다 — `docs/request/backend/tag-gap-endpoint.md`.
/// 관찰의 evidence로는 **3회 이상이지만 1.5배 미만인 태그**가 오지 않아
/// 막대의 비교 대상이 사라진다.
class _TagGapSection extends StatelessWidget {
  const _TagGapSection();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: SmallLabel('이야기별 갭')),
            Text(
              '내 평균 ${Sample.userAvgGap.toStringAsFixed(2)} · 점선은 ×1.5',
              style: AppType.sans(
                size: AppType.labelSize,
                color: t.faint,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const TagGapBars(
          rows: Sample.tagGaps,
          userAvgGap: Sample.userAvgGap,
        ),
        const SizedBox(height: Space.lg),
        Text(
          '세 번 이상 나온 이야기만 셉니다. 점선을 넘으면 발견이 됩니다.',
          style: AppType.sans(
            size: AppType.labelSize,
            color: t.faint,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.current, required this.onPick});

  final String current;
  final ValueChanged<String> onPick;

  static const _labels = {
    TrendRange.d7: '7일',
    TrendRange.d30: '30일',
    TrendRange.d90: '90일',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (final e in _labels.entries) ...[
          if (e.key != TrendRange.d7) const SizedBox(width: Space.sm),
          GestureDetector(
            onTap: () => onPick(e.key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: Space.tapMin,
              padding: const EdgeInsets.symmetric(horizontal: Space.lg + 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: e.key == current ? t.accent : t.line,
                ),
                borderRadius: const BorderRadius.all(Radii.control),
              ),
              alignment: Alignment.center,
              child: Text(
                e.value,
                style: AppType.sans(
                  size: AppType.captionSizeLg,
                  color: e.key == current ? t.paper : t.faint,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
