import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fixtures/sample_data.dart';
import '../../core/models/observation_models.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';

/// 홈 화면의 상태 — 지금은 샘플로 전환하고, API가 붙으면 프로바이더가 준다.
enum HomeState { normal, empty, loading, startBlocked, resumable, resumeExpired }

/// S01 오늘 (홈).
///
/// F2-01 대화 시작 · F7-06 최근 관찰 · F2-07 이어하기 제안.
///
/// **빈 상태가 도그푸딩 첫 며칠의 실제 화면이다** (spec 5-1 #4·#18) — 첫날은
/// 태그가 3회 미만이라 관찰이 생성되지 않는다. 억지 문구를 만들지 않는다
/// (FR-052).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.state = HomeState.normal});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isEmpty = state == HomeState.empty;
    final isLoading = state == HomeState.loading;
    final blocked = state == HomeState.startBlocked;
    final observation = Sample.observations.first;

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: SmallLabel('9월 14일 목요일')),
              _GearButton(onTap: () => context.push(Routes.settings)),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const SmallLabel('이번 주에 발견한 것'),
                  const SizedBox(height: Space.xl - Space.xs),

                  if (isLoading)
                    const SkeletonLines(widths: [1, 0.92, 0.58])
                  else if (isEmpty)
                    const EmptyState(
                      message: '아직 발견한 것이 없습니다.\n대화가 쌓이면 여기에 보입니다.',
                    )
                  else
                    _Observation(observation: observation),

                  const SizedBox(height: Space.xl),
                  const Hairline(),
                  const SizedBox(height: Space.xl),
                  const SmallLabel('지난 대화'),
                  const SizedBox(height: Space.lg + 2),

                  if (isLoading)
                    const SkeletonLines(widths: [0.8, 0.66], gap: 40)
                  else if (isEmpty)
                    Text(
                      '첫 대화를 기다리고 있습니다.',
                      style: AppType.sans(
                        size: AppType.captionSizeLg + 1,
                        color: t.faint,
                        height: 1.6,
                      ),
                    )
                  else
                    ...Sample.sessions.take(2).map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: Space.lg + 2),
                            child: _PastRow(
                              date: '${s.startedAt.month}.${s.startedAt.day}',
                              text: s.summary ?? '요약이 없습니다',
                            ),
                          ),
                        ),

                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),

          if (state == HomeState.resumable ||
              state == HomeState.resumeExpired)
            _ResumeBlock(expired: state == HomeState.resumeExpired),

          if (state != HomeState.resumable) ...[
            OutlineAction(
              label: blocked ? '다시 시도' : '오늘 이야기하기',
              icon: blocked
                  ? null
                  : Icon(Icons.mic_none, size: 17, color: t.paper),
              onPressed: blocked
                  ? null
                  : () => context.push(Routes.conversation),
            ),
            const SizedBox(height: Space.lg),
            Text(
              blocked
                  ? '지금은 대화를 시작할 수 없습니다. 잠시 후 다시 시도해 주세요.'
                  : '목소리는 분석 직후 삭제됩니다',
              textAlign: TextAlign.center,
              style: AppType.sans(
                size: blocked
                    ? AppType.captionSize
                    : AppType.smallLabelSize,
                color: blocked ? t.muted : t.faint,
                height: 1.7,
                letterSpacing: blocked ? null : 0.06 * AppType.smallLabelSize,
              ),
            ),
          ],
          // 홈은 아래가 스크롤이 아니라 CTA라 실제로 여백을 준다 — 칩이
          // 버튼을 덮으면 시작을 못 한다.
          SizedBox(height: Space.xs + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _Observation extends StatelessWidget {
  const _Observation({required this.observation});

  final Observation observation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final e = observation.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 관찰 문장은 명조로 — 사용자가 실제로 읽어야 하는 유일한 문장이다.
        Text(
          observation.sentence,
          style: AppType.serif(size: 27, color: t.paper),
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${e.tag} ${e.occurrences}회',
              style: AppType.sans(
                size: AppType.captionSize,
                color: t.muted,
                height: 1.2,
              ),
            ),
            const SizedBox(width: Space.md + 2),
            Container(width: 1, height: 11, color: t.line),
            const SizedBox(width: Space.md + 2),
            Text(
              '평균의 ${e.ratio.toStringAsFixed(2)}배',
              style: AppType.sans(
                size: AppType.captionSize,
                color: t.muted,
                height: 1.2,
              ),
            ),
          ],
        ),
        ActionLink(
          label: '근거가 된 대화 ${e.occurrences}건',
          onPressed: () =>
              context.push(Routes.evidenceOf(observation.observationId)),
        ),
      ],
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.date, required this.text});

  final String date;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            date,
            style: AppType.sans(
              size: AppType.captionSize,
              color: t.faint,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Text(
            text,
            style: AppType.sans(
              size: AppType.captionSizeLg + 1,
              color: t.muted,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// F2-07 이어하기 제안.
///
/// **남은 시간을 화면이 직접 말한다** — 이어하기로 새 7분을 주면 세션당 원가
/// 상한 $0.49가 뚫린다(NFR-06).
class _ResumeBlock extends StatelessWidget {
  const _ResumeBlock({required this.expired});

  final bool expired;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl - Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          const SizedBox(height: Space.xl - Space.xs),
          const SmallLabel('중단된 대화'),
          const SizedBox(height: Space.md),
          Text(
            expired
                ? '이어갈 수 있는 시간이 지났습니다. 새 대화로 시작합니다.'
                : '5분 전에 중단된 대화가 있습니다. 이어서 이야기할까요?',
            style: AppType.sans(
              size: AppType.bodySize,
              color: expired ? t.muted : t.paper,
              height: 1.7,
            ),
          ),
          if (!expired) ...[
            const SizedBox(height: Space.md),
            Text(
              '남은 시간 4분 42초 · 원래 7분 중 이미 쓴 시간을 뺀 값입니다',
              style: AppType.sans(
                size: AppType.captionSize,
                color: t.faint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Space.xl - Space.xs),
            Row(
              children: [
                Expanded(
                  child: FilledAction(
                    label: '이어서 하기',
                    height: 56,
                    onPressed: () => context.push(Routes.conversation),
                  ),
                ),
                const SizedBox(width: Space.sm),
                SizedBox(
                  width: 120,
                  child: OutlineAction(
                    label: '새로 시작',
                    height: 56,
                    onPressed: () => context.push(Routes.conversation),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GearButton extends StatelessWidget {
  const _GearButton({this.onTap});

  final VoidCallback? onTap;

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
          alignment: Alignment.topRight,
          child: Icon(Icons.settings_outlined, size: 18, color: t.faint),
        ),
      ),
    );
  }
}
