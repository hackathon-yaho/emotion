import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/account_unlink.dart';
import 'core/config/browser_url.dart';
import 'core/providers.dart';
import 'core/router/routes.dart';
import 'core/router/app_router.dart';
import 'core/session/app_session.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/app_frame.dart';

void main() {
  runApp(const ProviderScope(child: VoiceJournalApp()));
}

class VoiceJournalApp extends ConsumerStatefulWidget {
  const VoiceJournalApp({super.key});

  @override
  ConsumerState<VoiceJournalApp> createState() => _VoiceJournalAppState();
}

class _VoiceJournalAppState extends ConsumerState<VoiceJournalApp> {
  late final GoRouter _router = createRouter(ref.read(appSessionProvider));

  /// 부팅 때 한 번 — 카카오에서 돌아온 코드가 **탈퇴용**이면 여기서 끝낸다.
  ///
  /// 로그인 복귀는 S00이 처리하지만, 탈퇴 복귀는 이미 로그인된 상태라 S00을
  /// 지나지 않는다. 앱이 통째로 다시 뜨는 자리는 여기뿐이다 (F10-03).
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishUnlink());
  }

  Future<void> _finishUnlink() async {
    final outcome = await finishUnlinkIfReturned(
      storage: ref.read(tokenStorageProvider),
      repo: ref.read(journalRepositoryProvider),
      here: Uri.base,
    );
    if (outcome == UnlinkOutcome.none) return;
    // 코드는 1회용이다 — 새로고침이 같은 코드를 다시 보내지 않게 지운다.
    clearQuery();
    if (!mounted) return;
    switch (outcome) {
      case UnlinkOutcome.done:
        await ref.read(appSessionProvider).reset();
        _router.go(Routes.onboarding);
      case UnlinkOutcome.failed:
        // **기기를 비우지 않는다.** 비우면 서버에 남은 데이터를 지울 방법이
        // 없어진다 — 설정에서 다시 누를 수 있는 상태로 둔다.
        _messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('지금은 지울 수 없습니다. 잠시 후 다시 시도해 주세요.'),
          ),
        );
      case UnlinkOutcome.cancelled || UnlinkOutcome.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      // 제품 이름 미확정 (PRD §14-6). 확정되면 여기와 web/index.html·manifest를
      // 함께 고친다.
      title: '감정 케어 보이스 저널',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,

      // 넓은 화면 폭 규칙은 여기 한 곳에서만 적용한다 (design-system §2).
      // 라우트마다 따로 걸면 셸 안/밖이 다시 어긋난다.
      //
      // `builder`는 라우터 **위에** 한 번만 만들어져 라우트가 바뀌어도 다시
      // 불리지 않는다. §2-1 예외를 라우트로 판정하려면 델리게이트를 직접
      // 구독해야 한다.
      builder: (context, child) => ListenableBuilder(
        listenable: _router.routerDelegate,
        builder: (context, _) => AppFrame(
          uri: _router.routerDelegate.currentConfiguration.uri,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
