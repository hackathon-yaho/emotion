import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// 다크·라이트 두 테마. 기본값은 시스템 설정을 따르고 S06에서 수동 전환한다.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark, AppTokens.dark);
  static ThemeData light() => _build(Brightness.light, AppTokens.light);

  static ThemeData _build(Brightness brightness, AppTokens t) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: t.accent,
        brightness: brightness,
      ).copyWith(
        surface: t.bg,
        onSurface: t.paper,
        primary: t.accent,
        onPrimary: t.onAccent,
        outline: t.line,
      ),
      // 카드를 쓰지 않는 언어이므로 Material의 카드 그림자를 죽인다.
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: t.paper,
        displayColor: t.paper,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.lift,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radii.sheet),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          minimumSize: const Size(0, Space.tapMin),
          textStyle: AppType.sans(size: AppType.captionSizeLg, color: t.accent),
        ),
      ),
    );
  }
}

/// `context.tokens` 로 토큰을 꺼낸다.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
