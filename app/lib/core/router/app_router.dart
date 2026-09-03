import 'package:go_router/go_router.dart';

import '../../features/conversation/conversation_screen.dart';
import '../../features/conversation/summary_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/discover/evidence_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/records/record_detail_screen.dart';
import '../../features/records/records_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/trend/trend_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

/// spec §4의 화면 11개를 라우트로 옮긴 것.
///
/// 하단 탭 4개(오늘·발견·추세·기록)는 셸 라우트 안에 두고, 대화·근거·상세·
/// 설정은 셸 밖에 둔다 — 탭 바가 없는 화면들이다.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: Routes.onboarding,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          final tab = AppTab.values.firstWhere(
            (t) => location.startsWith(t.path),
            orElse: () => AppTab.home,
          );
          return AppShell(
            currentTab: tab,
            onTabSelected: (t) => context.go(t.path),
            child: child,
          );
        },
        routes: [
          GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: Routes.discover,
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(path: Routes.trend, builder: (context, state) => const TrendScreen()),
          GoRoute(
            path: Routes.records,
            builder: (context, state) => const RecordsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: Routes.conversation,
        builder: (context, state) => const ConversationScreen(),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) => const SummaryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.evidence,
        builder: (context, state) => const EvidenceScreen(),
      ),
      GoRoute(
        path: Routes.recordDetail,
        builder: (context, state) => const RecordDetailScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
