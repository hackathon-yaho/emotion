import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/observation_models.dart';
import '../../core/models/paged.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/meta_row.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';

/// S03 발견.
///
/// F7-06 관찰 조회 · F7-08 피드백(P1).
///
/// 관찰이 0건이면 안내 문구만 띄우고 **가짜 관찰을 만들지 않는다** (FR-052).
/// 빈 상태에는 **명조를 쓰지 않는다** — 명조는 실제로 발견된 문장에만 쓰는
/// 서체다 (design-system §7-11).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  /// 관찰당 1회, `agree`/`disagree`. **취소·이유 입력은 없다** (spec F7-08).
  ///
  /// 화면에 남기는 것은 눌린 상태뿐이고, 값은 서버가 기록한다.
  final _answers = <String, String>{};

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('발견'),
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
    return AsyncView<Paged<Observation>>(
      value: ref.watch(observationsProvider),
      loading: const Column(
        children: [
          Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xxl - Space.xs),
            child: SkeletonLines(widths: [1, 0.72], gap: 30),
          ),
          Hairline(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: Space.xxl - Space.xs),
            child: SkeletonLines(widths: [1, 0.72], gap: 30),
          ),
          Hairline(),
        ],
      ),
      isEmpty: (d) => d.isEmpty,
      empty: const EmptyState(
        message: '아직 발견한 것이 없습니다. 대화가 쌓이면 여기에 보입니다.',
        detail: '같은 이야기가 세 번 이상 나오고, 그때 목소리가 평소와 달라야 발견으로 칩니다.',
      ),
      onRetry: () => ref.invalidate(observationsProvider),
      data: (d) => Column(
        children: [
          for (final o in d.items)
            _ObservationRow(
              observation: o,
              answer: _answers[o.observationId],
              onAnswer: (v) => _answer(o.observationId, v),
            ),
          const Hairline(),
        ],
      ),
    );
  }

  /// F7-08 — 누른 즉시 화면을 바꾸고 서버에 보낸다.
  ///
  /// **실패해도 되돌리지 않는다.** 피드백은 지표 수집이라(§1.4) 한 건이
  /// 유실되는 것보다 사용자가 누른 것이 취소되는 편이 나쁘다.
  void _answer(String observationId, String value) {
    setState(() => _answers[observationId] = value);
    ref
        .read(journalRepositoryProvider)
        .sendFeedback(observationId, agree: value == 'agree')
        .ignore();
  }
}

class _ObservationRow extends StatelessWidget {
  const _ObservationRow({
    required this.observation,
    required this.answer,
    required this.onAnswer,
  });

  final Observation observation;
  final String? answer;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = observation.evidence;
    final createdAt = observation.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 발견된 날짜 — 정렬이 최신순이므로 날짜가 없으면 순서의 의미가
              // 보이지 않는다 (design-system §7-20).
              SmallLabel('${createdAt.month}월 ${createdAt.day}일 발견'),
              const SizedBox(height: Space.md),
              Text(
                observation.sentence,
                style: AppType.serif(size: 20, color: t.paper),
              ),
              const SizedBox(height: Space.lg),
              MetaRow([
                '${e.tag} ${e.occurrences}회',
                '평균의 ${e.ratio.toStringAsFixed(2)}배',
              ]),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  ActionLink(
                    label: '근거 보기',
                    onPressed: () => context
                        .push(Routes.evidenceOf(observation.observationId)),
                  ),
                  const Spacer(),
                  if (answer == null) ...[
                    _FeedbackButton(
                      label: '맞아요',
                      strong: true,
                      onTap: () => onAnswer(FeedbackValue.agree),
                    ),
                    const SizedBox(width: Space.xl),
                    _FeedbackButton(
                      label: '아니에요',
                      strong: false,
                      onTap: () => onAnswer(FeedbackValue.disagree),
                    ),
                  ] else
                    SizedBox(
                      height: Space.tapMin - 4,
                      child: Center(
                        child: Text(
                          answer == FeedbackValue.agree
                              ? '"맞아요"로 답했습니다'
                              : '"아니에요"로 답했습니다',
                          style: AppType.sans(
                            size: AppType.captionSize,
                            color: t.faint,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.label,
    required this.strong,
    required this.onTap,
  });

  final String label;
  final bool strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: Space.tapMin - 4,
        child: Center(
          child: Text(
            label,
            style: AppType.sans(
              size: AppType.captionSizeLg,
              color: strong ? t.muted : t.faint,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
