import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/trend_models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
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
class TrendScreen extends ConsumerWidget {
  const TrendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final range = ref.watch(trendRangeProvider);
    final trend = ref.watch(trendProvider);

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('추세'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 36,
                // 떠 있는 탭 칩 높이만큼 안쪽에 남긴다 (TabPill.reserve).
                bottom: Space.xl + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DoubledText('말한 내용과 목소리'),
                  const SizedBox(height: Space.xl),
                  _RangePicker(
                    current: range,
                    onPick: (r) =>
                        ref.read(trendRangeProvider.notifier).state = r,
                  ),
                  const SizedBox(height: Space.xl),

                  AsyncView<Trend>(
                    value: trend,
                    loading: const SkeletonLines(widths: [1, 1, 1, 1], gap: 50),
                    isEmpty: (d) => d.points.isEmpty,
                    empty: const EmptyState(
                      message:
                          '아직 그릴 기록이 없습니다.\n대화가 쌓이면 말한 내용과 목소리를 나란히 보여드립니다.',
                    ),
                    onRetry: () => ref.invalidate(trendProvider),
                    data: (d) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TwoLineChart(
                          points: d.points,
                          highlights: d.highlights,
                          // 음영 구간의 **시작 날짜**로 간다. 계약은 세션 id를
                          // 주지 않으므로 날짜로 상세를 찾는다.
                          onHighlightTap: () => _openHighlight(context, ref, d),
                        ),
                        ChartDateAxis(points: d.points),
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

                        // F9-03은 조건을 만족하는 태그가 없으면 `[]`로 온다.
                        // **없으면 절을 통째로 그리지 않는다** — 빈 막대를
                        // 그리지 않는다 (§7 결정 11).
                        if (d.tagGaps.isNotEmpty && d.userAvgGap != null) ...[
                          const SizedBox(height: Space.xxl),
                          const Hairline(),
                          const SizedBox(height: Space.xl),
                          _TagGapSection(
                            rows: d.tagGaps,
                            userAvgGap: d.userAvgGap!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 음영 구간을 눌렀을 때 — **그 구간의 첫 날 기록으로** 간다.
///
/// 계약 §2-8의 `highlights`는 세션 id를 주지 않는다. 날짜로 목록에서 찾고,
/// 못 찾으면 아무 데도 가지 않는다 — 엉뚱한 대화를 열면 근거가 거짓이 된다.
Future<void> _openHighlight(BuildContext context, WidgetRef ref, Trend d) async {
  if (d.highlights.isEmpty) return;
  final day = d.highlights.first.from;
  final list = await ref.read(journalRepositoryProvider).sessions();
  final match = list.items.where((s) => s.startedAt.toIso8601String().startsWith(day));
  if (match.isEmpty || !context.mounted) return;
  context.push(Routes.recordDetailOf(match.first.sessionId));
}

/// F9-03 이야기별 갭.
///
/// `GET /api/trend`의 `tagGaps`·`userAvgGap`으로 온다 (계약 v1.4 §2-8).
/// 관찰의 evidence로는 **3회 이상이지만 1.5배 미만인 태그**가 오지 않아
/// 막대의 비교 대상이 사라진다 — 그래서 별도 필드가 필요했다.
class _TagGapSection extends StatelessWidget {
  const _TagGapSection({required this.rows, required this.userAvgGap});

  final List<TagGap> rows;
  final double userAvgGap;

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
              '내 평균 ${userAvgGap.toStringAsFixed(2)} · 점선은 ×1.5',
              style: AppType.sans(
                size: AppType.labelSize,
                color: t.faint,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TagGapBars(rows: rows, userAvgGap: userAvgGap),
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
