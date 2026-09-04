import 'package:go_router/go_router.dart';

import '../session/app_session.dart';

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
GoRouter createRouter(AppSession session) {
  return GoRouter(
    initialLocation: Routes.onboarding,
    refreshListenable: session,

    /// **동의 없이 대화 화면으로 진입할 수 없다** (F1-05 수용 기준).
    ///
    /// 웹은 주소창에 URL을 치면 바로 들어가므로 가드가 없으면 온보딩이
    /// 통째로 건너뛰어진다. 네이티브보다 더 직접적인 우회 경로다.
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == Routes.onboarding;

      switch (session.status) {
        // 저장소를 아직 못 읽었다 — 판단을 보류하고 그대로 둔다.
        case GateStatus.unknown:
          return null;

        // 고지 미동의·미로그인 → S00으로. 이미 S00이면 그대로.
        case GateStatus.needsOnboarding:
        case GateStatus.needsLogin:
          return atOnboarding ? null : Routes.onboarding;

        // 통과한 사용자가 S00에 머무를 이유가 없다.
        case GateStatus.ready:
          return atOnboarding ? Routes.home : null;
      }
    },
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
        builder: (context, state) => ConversationScreen(
          // 프로토타입 전환·데모 모드는 쿼리로만 켠다. 실제 화면에는 없다.
          showStatePicker: state.uri.queryParameters['picker'] == '1',
          demoMode: state.uri.queryParameters['demo'] == '1',
          openCrisis: state.uri.queryParameters['crisis'] == '1',
        ),
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
