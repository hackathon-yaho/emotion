import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/record_models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/confirm_sheet.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/meta_row.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';

/// S05-1 대화 상세 (F9-05 · F10-01).
///
/// **갭 수치는 이 화면에서는 노출된다** — 대화 화면과 구분되는 지점이다
/// (FR-031). **assistant 턴은 valence·gap이 전부 null**이고, 측정 대상은
/// 사용자 발화뿐이므로 측정값을 붙이지 않는다.
///
/// 삭제 확인 시트는 **연쇄 무효화를 미리 말한다** (FR-081) — 근거 대화가
/// 삭제됐는데 관찰만 남으면 그 관찰은 그 순간 "근거 없는 문장"이 된다.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionDetailProvider(sessionId);
    return ScreenScaffold(
      topPadding: 40,
      child: AsyncView<SessionDetail>(
        value: ref.watch(provider),
        loading: const SkeletonLines(widths: [0.5, 1, 1, 0.8], gap: 34),
        onRetry: () => ref.invalidate(provider),
        data: (d) => _content(context, ref, d),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, SessionDetail d) {
    final t = context.tokens;
    final at = d.startedAt;
    final minutes = d.durationSec ~/ 60;
    final seconds = d.durationSec % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              _IconTap(
                icon: Icons.chevron_left,
                onTap: () => context.pop(),
                align: Alignment.centerLeft,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context, ref, d),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: Space.tapMin,
                  child: Center(
                    child: Text(
                      '삭제',
                      style: AppType.sans(
                        size: AppType.captionSize,
                        color: t.muted,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Space.xl - Space.xs),
                  SmallLabel(
                    '${at.month}월 ${at.day}일 · '
                    '${at.hour.toString().padLeft(2, '0')}:'
                    '${at.minute.toString().padLeft(2, '0')} · '
                    '$minutes분 $seconds초',
                  ),
                  const SizedBox(height: Space.md + 2),
                  if (d.summary != null)
                    Text(
                      d.summary!,
                      style: AppType.serif(size: 22, color: t.paper),
                    ),

                  // 당연한 것은 적지 않는다 — user_end는 표시하지 않는다
                  // (design-system §7-21).
                  if (d.endReason == 'hard_cut' || d.endReason == 'timeout') ...[
                    const SizedBox(height: Space.md),
                    Text(
                      d.endReason == 'hard_cut'
                          ? '7분에 자동으로 마무리됐습니다'
                          : '연결이 끊겨 정리됐습니다',
                      style: AppType.sans(
                        size: AppType.captionSize,
                        color: t.faint,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: Space.xxl - Space.xs),
                  const Hairline(),
                  for (final turn in d.turns) _TurnRow(turn: turn),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SessionDetail d,
  ) async {
    final t = context.tokens;
    final ok = await showConfirmSheet(
      context,
      title: '이 대화를 지울까요?',
      confirmLabel: '지우기',
      body: [
        TextSpan(
          text: '${d.startedAt.month}월 ${d.startedAt.day}일 대화와 '
              '발화 ${d.turns.length}건이 지워집니다.\n\n',
        ),
        TextSpan(
          text: '이 대화를 근거로 한 발견 1건도 함께 사라집니다.',
          style: TextStyle(color: t.paper),
        ),
        const TextSpan(
          text: ' 근거가 3건 미만이 되면 그 발견은 더 이상 성립하지 않기 때문입니다.',
        ),
      ],
    );
    if (!ok) return;
    // **삭제는 서버가 하고, 연쇄 무효화 결과도 서버가 준다** (§2-12).
    // 목록·발견·추세가 같이 달라지므로 셋 다 무효화한다.
    await ref.read(journalRepositoryProvider).deleteSession(d.sessionId);
    ref.invalidate(sessionsProvider);
    ref.invalidate(observationsProvider);
    ref.invalidate(trendProvider);
    if (context.mounted) context.pop();
  }
}

class _TurnRow extends StatelessWidget {
  const _TurnRow({required this.turn});

  final Turn turn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // AI 발화 — 왼쪽 세로선으로 구분하고 측정값을 붙이지 않는다.
    if (!turn.isUser) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xl - Space.xs),
            // 세로선이 문장 높이를 따라가게 한다. stretch만 쓰면 스크롤 안에서
            // 높이가 무한이라 뒤 항목이 밀린다.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 2, color: t.line),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      turn.transcript,
                      style: AppType.sans(
                        size: AppType.captionSizeLg + 1,
                        color: t.muted,
                        height: 1.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Hairline(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl - 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                turn.transcript,
                style: AppType.sans(
                  size: AppType.bodySize,
                  color: t.paper,
                  height: 1.75,
                ),
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ChannelValue(color: t.cool, value: _fmt(turn.textValence)),
                  const SizedBox(width: Space.md + 2),
                  ChannelValue(color: t.warm, value: _fmt(turn.voiceValence)),
                  const SizedBox(width: Space.md + 2),
                  Container(width: 1, height: 10, color: t.line),
                  const SizedBox(width: Space.md + 2),
                  Text(
                    '갭 ${_fmt(turn.gap)}',
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.muted,
                      height: 1.2,
                    ),
                  ),
                  if (turn.tags.isNotEmpty) ...[
                    const SizedBox(width: Space.md + 2),
                    Text(
                      turn.tags.join(' · '),
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
        const Hairline(),
      ],
    );
  }

  static String _fmt(double? v) {
    if (v == null) return '—';
    return '${v < 0 ? '−' : ''}${v.abs().toStringAsFixed(2)}';
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.onTap,
    required this.align,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: Space.tapMin,
        height: Space.tapMin,
        child: Align(
          alignment: align,
          child: Icon(icon, size: 24, color: t.muted),
        ),
      ),
    );
  }
}
