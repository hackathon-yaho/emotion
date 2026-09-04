import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/observation_models.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/small_label.dart';

/// S01 오늘 (홈).
///
/// F2-01 대화 시작 · F7-06 최근 관찰 · F2-07 이어하기 제안.
///
/// **빈 상태가 도그푸딩 첫 며칠의 실제 화면이다** (spec 5-1 #4·#18) — 첫날은
/// 태그가 3회 미만이라 관찰이 생성되지 않는다. 억지 문구를 만들지 않는다
/// (FR-052).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final me = ref.watch(meProvider);
    final observations = ref.watch(observationsProvider);
    final sessions = ref.watch(sessionsProvider);

    final isLoading = observations.isLoading || sessions.isLoading;
    final observation = observations.valueOrNull?.items.firstOrNull;
    final recent = sessions.valueOrNull?.items.take(2).toList() ?? const [];

    // **실패를 빈 상태로 바꿔 말하지 않는다.** "아직 발견한 것이 없습니다"는
    // 사실 주장이라, 못 불러온 것을 그렇게 적으면 거짓이 된다.
    final failure = observations.error ?? sessions.error;
    final isEmpty = !isLoading && failure == null && observation == null;

    // F2-07 — 비정상 중단으로 열려 있는 세션 (§2-2 `openSession`).
    final open = me.valueOrNull?.openSession;
    final resumable = open != null && open.isResumable;
    final resumeExpired = open != null && !open.isResumable;

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SmallLabel(_today())),
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
                  else if (failure != null)
                    AsyncErrorBlock(
                      error: failure,
                      onRetry: () {
                        ref.invalidate(observationsProvider);
                        ref.invalidate(sessionsProvider);
                        ref.invalidate(meProvider);
                      },
                    )
                  else if (isEmpty)
                    const EmptyState(
                      message: '아직 발견한 것이 없습니다.\n대화가 쌓이면 여기에 보입니다.',
                    )
                  else
                    _Observation(observation: observation!),

                  const SizedBox(height: Space.xl),
                  const Hairline(),
                  const SizedBox(height: Space.xl),
                  const SmallLabel('지난 대화'),
                  const SizedBox(height: Space.lg + 2),

                  if (isLoading)
                    const SkeletonLines(widths: [0.8, 0.66], gap: 40)
                  else if (failure != null)
                    const SizedBox.shrink()
                  else if (recent.isEmpty)
                    Text(
                      '첫 대화를 기다리고 있습니다.',
                      style: AppType.sans(
                        size: AppType.captionSizeLg + 1,
                        color: t.faint,
                        height: 1.6,
                      ),
                    )
                  else
                    ...recent.map(
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

          if (resumable || resumeExpired) _ResumeBlock(expired: resumeExpired),

          if (!resumable) ...[
            OutlineAction(
              label: '오늘 이야기하기',
              icon: Icon(Icons.mic_none, size: 17, color: t.paper),
              onPressed: () => context.push(Routes.conversation),
            ),
            const SizedBox(height: Space.lg),
            Text(
              '목소리는 분석 직후 삭제됩니다',
              textAlign: TextAlign.center,
              style: AppType.sans(
                size: AppType.smallLabelSize,
                color: t.faint,
                height: 1.7,
                letterSpacing: 0.06 * AppType.smallLabelSize,
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

/// 오늘 날짜 — "9월 14일 목요일".
///
/// **서버가 주는 값이 아니다.** 사용자의 기기 시각을 쓴다. 계약의 날짜는
/// `Asia/Seoul` 기준이라 해외에서 하루가 어긋날 수 있는데, 도그푸딩·심사
/// 모두 국내라 지금은 문제가 되지 않는다.
String _today() {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final now = DateTime.now();
  return '${now.month}월 ${now.day}일 ${days[now.weekday - 1]}요일';
}
