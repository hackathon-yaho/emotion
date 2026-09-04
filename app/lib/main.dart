import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
