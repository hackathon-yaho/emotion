import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fixtures/sample_data.dart';
import '../../core/models/record_models.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';

/// S05 대화 기록 (F9-04).
///
/// 항목에 `tags`·`gapAvg`를 표시한다 (design-system §7-8) — 기록 화면은 갭
/// 노출이 허용되고(FR-031), 목록에서 그날의 주제와 갭을 훑을 수 있어야 상세로
/// 들어갈 이유가 생긴다.
///
/// 페이징은 기본 20개, **"더 보기" 버튼 없이** 바닥에서 이어 불러온다 (§7-22).
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, this.isEmpty = false, this.isLoading = false});

  final bool isEmpty;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('기록'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 36,
                // 떠 있는 탭 칩 높이만큼 안쪽에 남긴다 (TabPill.reserve).
                bottom: Space.xl + MediaQuery.paddingOf(context).bottom,
              ),
              child: _body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (isLoading) {
      return const Column(
        children: [
          Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xl),
            child: SkeletonLines(widths: [0.7, 0.44], gap: 22),
          ),
          Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xl),
            child: SkeletonLines(widths: [0.7, 0.44], gap: 22),
          ),
          Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xl),
            child: SkeletonLines(widths: [0.7, 0.44], gap: 22),
          ),
          Hairline(),
        ],
      );
    }

    if (isEmpty) {
      return const EmptyState(message: '아직 대화가 없습니다.');
    }

    return Column(
      children: [
        for (final s in Sample.sessions) _RecordRow(session: s),
        const Hairline(),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = session;
    final minutes = s.durationSec ~/ 60;
    final seconds = s.durationSec % 60;

    return Column(
      children: [
        const Hairline(),
        GestureDetector(
          onTap: () => context.push(Routes.recordDetailOf(s.sessionId)),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xl - Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${s.startedAt.month}.${s.startedAt.day}',
                    style: AppType.sans(
                      size: AppType.captionSize,
                      color: t.faint,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.summary ?? '요약이 없습니다',
                        style: AppType.sans(
                          size: AppType.captionSizeLg + 1,
                          color: t.paper,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: Space.sm + 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          Text(
                            '$minutes분 $seconds초 · ${s.turnCount}턴',
                            style: AppType.sans(
                              size: AppType.labelSize,
                              color: t.faint,
                              height: 1.2,
                            ),
                          ),
                          Container(width: 1, height: 10, color: t.line),
                          if (s.gapAvg != null)
                            Text(
                              '갭 ${s.gapAvg!.toStringAsFixed(2)}',
                              style: AppType.sans(
                                size: AppType.labelSize,
                                color: t.muted,
                                height: 1.2,
                              ),
                            ),
                          if (s.tags.isNotEmpty) ...[
                            Container(width: 1, height: 10, color: t.line),
                            Text(
                              s.tags.join(' · '),
                              style: AppType.sans(
                                size: AppType.labelSize,
                                color: t.faint,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
