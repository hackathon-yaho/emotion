import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/session/app_session.dart';
import 'core/theme/app_theme.dart';

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
    );
  }
}
