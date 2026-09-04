import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/meta_row.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S02-1 대화 종료 요약 (F2-05).
///
/// `summary`는 **null일 수 있다** — 생성 실패 시 요약 영역을 숨기고 대화
/// 기록은 남는다 (계약서 §1-3).
///
/// **`gapAvg`를 표시하지 않는다** (design-system §7-7). 계약서 종료 응답에
/// 있지만 FR-031이 갭을 "기록·트렌드 화면에서만"이라 했다 — 대화를 마친
/// 직후에 숫자를 보이는 것은 대화 화면의 연장으로 읽힌다.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // 종료 응답(§2-6)은 한 번만 온다. 목록을 다시 불러 첫 항목을 쓰지 않는다 —
    // 그것이 "방금 끝낸 대화"라는 보장이 없다.
    final s = ref.watch(lastSessionEndProvider);
    if (s == null) return const _NoSummary();
    final minutes = s.durationSec ~/ 60;
    final seconds = s.durationSec % 60;

    return ScreenScaffold(
      topPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmallLabel('오늘의 대화'),
                const SizedBox(height: Space.xxl - Space.xs),
                if (s.summary != null)
                  Text(
                    s.summary!,
                    style: AppType.serif(size: 27, color: t.paper),
                  ),
                const SizedBox(height: Space.xxl - Space.xs),
                MetaRow(['$minutes분 $seconds초', '${s.turnCount}턴']),
              ],
            ),
          ),
          FilledAction(
            label: '홈으로',
            onPressed: () => context.go(Routes.home),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// 요약 없이 이 화면에 온 경우 — 주소를 직접 치거나 새로고침한 경우다.
///
/// **가짜 요약을 보여주지 않는다.** 방금 끝낸 대화가 없으면 없다고 말한다.
class _NoSummary extends StatelessWidget {
  const _NoSummary();

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      topPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Center(
              child: EmptyState(message: '방금 끝낸 대화가 없습니다.'),
            ),
          ),
          FilledAction(label: '홈으로', onPressed: () => _go(context)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _go(BuildContext context) => context.go(Routes.home);
}
