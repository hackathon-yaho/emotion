import 'package:flutter/material.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import 'tab_pill.dart';

/// 앱 셸 — 하단 탭 4개.
///
/// 탭은 [TabPill]이 그린다 — **콘텐츠 위에 떠 있는 반투명 알약 칩**이라
/// 셸은 [Stack]으로 겹치고, 칩이 차지하는 높이를 `MediaQuery`의 아래
/// 여백으로 화면에 넘긴다. 각 탭 화면은 그 값을 **스크롤 뷰 안쪽** 여백으로
/// 받아 칩에 가리지 않는다.
///
/// 넓은 화면에서 폭을 고정하는 일은 하지 않는다 — `AppFrame`이 모든 라우트에
/// 한 번에 적용한다 (§2).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentTab,
    required this.onTabSelected,
  });

  final Widget child;
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reserve = TabPill.reserve(context);

    return Material(
      color: context.tokens.bg,
      child: Stack(
        children: [
          // 칩 높이를 아래 여백으로 알려 준다. `ScreenScaffold`가
          // `SafeArea(bottom: false)`라 이 값은 화면이 직접 쓴다.
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: reserve),
            ),
            child: child,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TabPill(current: currentTab, onSelected: onTabSelected),
          ),
        ],
      ),
    );
  }
}
