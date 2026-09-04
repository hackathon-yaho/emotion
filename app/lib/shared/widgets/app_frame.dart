import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// 넓은 화면에서 화면 폭을 정하는 **단 하나의 지점** (design-system §2).
///
/// `MaterialApp.router`의 `builder`에 한 번만 걸어 **모든 라우트**가 같은 규칙을
/// 지나가게 한다. 셸 라우트(탭 4개)와 셸 밖 라우트(대화·근거·상세·설정)가
/// 서로 다르게 보이던 문제가 여기서 갈렸다 — 폭 결정이 `AppShell` 안에만
/// 있었고 셸 밖 화면은 전폭으로 늘어났다.
///
/// 화면 쪽에 폭 제한을 추가하지 않는다. 넓은 화면 규칙이 두 곳에 생기면
/// 다시 어긋난다.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.uri, required this.child});

  /// 현재 라우트. §2-1 예외 두 곳을 판정하는 데만 쓴다.
  final Uri uri;
  final Widget child;

  /// 앱 셸 최대 폭 (§2). 420을 넘기면 한 손 UI가 늘어져 보인다.
  static const shellWidth = 420.0;

  /// 분기점 하나. `< 600` 전폭 / `>= 600` 중앙 고정 + 배경 (§2).
  static const breakpoint = 600.0;

  /// §2-1 예외 1 — S04 트렌드의 최대 폭. 심사장 프로젝터에서 두 선이
  /// 갈라진 것이 뒷줄까지 보여야 한다.
  static const trendWidth = 900.0;

  /// §2-1 예외 2 — 데모 모드 오른쪽 패널 폭 (`>= 600`).
  static const demoPanelWidth = 240.0;

  /// 중앙 고정일 때 프레임 바깥에 남기는 최소 여백.
  static const gutter = Space.xxl;

  /// 이 라우트가 셸 폭을 넘겨도 되는가 (§2-1).
  ///
  /// 예외는 **문서에 적힌 두 곳뿐이다.** 늘리고 싶으면 design-system §2-1을
  /// 먼저 고친다.
  static double frameWidthFor(Uri uri) {
    if (uri.path == Routes.trend) return trendWidth;
    if (uri.path == Routes.conversation &&
        uri.queryParameters['demo'] == '1') {
      return shellWidth + Space.xl + demoPanelWidth;
    }
    return shellWidth;
  }

  /// 데모 오버레이를 오른쪽 패널로 그려도 되는 폭인지 (§2-1).
  static bool hasSidePanel(double availableWidth) =>
      availableWidth >= shellWidth + Space.xl + demoPanelWidth;

  @override
  Widget build(BuildContext context) {
    final target = frameWidthFor(uri);

    return Material(
      color: context.tokens.bg,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < breakpoint) return child;
          // 예외 화면은 남는 폭까지만 늘린다. 셸 폭보다 좁아지지는 않는다.
          final width = math.max(
            shellWidth,
            math.min(target, c.maxWidth - gutter * 2),
          );
          return Center(child: SizedBox(width: width, child: child));
        },
      ),
    );
  }
}
