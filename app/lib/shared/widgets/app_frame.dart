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

  /// 현재 라우트. §2-1 예외 한 곳(데모 모드)을 판정하는 데만 쓴다.
  final Uri uri;
  final Widget child;

  /// 앱 셸 최대 폭 (§2). 420을 넘기면 한 손 UI가 늘어져 보인다.
  static const shellWidth = 420.0;

  /// 분기점 하나. `< 600` 전폭 / `>= 600` 중앙 고정 + 배경 (§2).
  static const breakpoint = 600.0;

  /// §2-1 예외 — 데모 모드 오른쪽 패널 폭 (`>= 600`).
  static const demoPanelWidth = 240.0;

  /// 중앙 고정일 때 프레임 바깥에 남기는 최소 여백.
  static const gutter = Space.xxl;

  /// 이 라우트가 셸 폭을 넘겨도 되는가 (§2-1).
  ///
  /// 예외는 **문서에 적힌 한 곳뿐이다** — 데모 모드. 늘리고 싶으면
  /// design-system §2-1을 먼저 고친다.
  ///
  /// **S04 트렌드는 예외가 아니다.** 한때 그래프를 900까지 넓혔는데, 그
  /// 근거(30일에서 점 마커가 살아남는 폭)가 **모바일에서는 성립하지
  /// 않았다** — `< 600`은 전폭이라 넓힐 여지가 없고, 매일 쓰는 환경이
  /// 그쪽이다. 밀도 문제는 폭이 아니라 차트가 푼다
  /// ([TwoLineChart]의 선택적 마커).
  static double frameWidthFor(Uri uri) {
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
    final t = context.tokens;
    final target = frameWidthFor(uri);

    return LayoutBuilder(
      builder: (context, c) {
        // 좁은 화면은 컨텐츠가 화면 전체다 — 바깥이 없다.
        if (c.maxWidth < breakpoint) {
          return Material(color: t.bg, child: child);
        }

        // 예외 화면은 남는 폭까지만 늘린다. 셸 폭보다 좁아지지는 않는다.
        final width = math.max(
          shellWidth,
          math.min(target, c.maxWidth - gutter * 2),
        );

        // 바깥은 `desk`, 컨텐츠는 `bg`. 두 색을 나누고 경계에 헤어라인을 둬야
        // 컨텐츠가 "책상 위에 놓인 한 장"으로 읽힌다 — 같은 색이면 화면
        // 전체가 한 덩어리가 되어 near-black이 검정으로 보인다.
        // 헤어라인은 컨텐츠 폭 **바깥**에 둔다. 안쪽 테두리로 넣으면 셸
        // 폭이 418로 줄어 화면마다 폭이 달라진다.
        return Material(
          color: t.desk,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Edge(color: t.line),
                SizedBox(
                  width: width,
                  child: ColoredBox(color: t.bg, child: child),
                ),
                _Edge(color: t.line),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 컨텐츠 영역 경계의 1px 세로선.
class _Edge extends StatelessWidget {
  const _Edge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(width: 1, child: ColoredBox(color: color));
}
