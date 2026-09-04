import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_frame.dart';

/// 하단 탭 — **떠 있는 반투명 알약 칩** (design-system §7-7, 2026-09-04 결정).
///
/// 「카드를 쓰지 않는다」(§1)의 **유일한 예외**다. 앱 담당이 "메뉴 한정으로는
/// 아이콘까지 붙인 칩이 낫다"고 판단해 채택했다. 예외를 좁게 두기 위한 제약이
/// 셋 있다.
///
/// - **면색은 `bg`에 알파를 준 것이다.** `lift`를 쓰지 않는다 — 그 토큰은
///   시트·오버레이 전용이고, 여기 쓰면 §4 규칙이 무너진다
/// - **아이콘은 여기서만 쓴다.** 본문·목록·헤더에 아이콘을 늘리지 않는다
/// - **블러는 탭이 있는 4개 화면에만 걸린다.** S02 대화 화면에는 칩이 없어
///   움직이는 링 위에서 `BackdropFilter`가 돌지 않는다
class TabPill extends StatelessWidget {
  const TabPill({super.key, required this.current, required this.onSelected});

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  static const height = 62.0;
  static const bottomMargin = Space.lg;
  static const blurSigma = 14.0;

  /// 칩이 콘텐츠 위에 떠 있으므로 그 높이를 화면에 알려 준다.
  ///
  /// 탭 화면들은 이 값을 스크롤 뷰의 **안쪽** 아래 여백으로 받는다 — 그래야
  /// 스크롤 중에는 글자가 칩 밑을 지나가고(반투명이 보이는 이유), 멈췄을 때는
  /// 칩에 가리지 않는다.
  static double reserve(BuildContext context) =>
      height +
      bottomMargin +
      Space.lg +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: EdgeInsets.only(
        left: Space.screenH,
        right: Space.screenH,
        bottom: bottomMargin + MediaQuery.viewPaddingOf(context).bottom,
      ),
      // §2-1로 넓어지는 화면(S04)에서도 **칩은 셸 폭에 고정한다.** 내비게이션이
      // 화면마다 늘어나면 아이콘 간격이 달라져 같은 메뉴로 안 읽힌다.
      child: _CappedWidth(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.bg.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: t.line, width: 1),
              ),
              child: SizedBox(
                height: height,
                child: Row(
                  children: [
                    for (final tab in AppTab.values)
                      Expanded(
                        child: _TabItem(
                          tab: tab,
                          selected: tab == current,
                          onTap: () => onSelected(tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 칩 폭 상한 — 셸 폭(420)에서 좌우 여백을 뺀 값.
class _CappedWidth extends StatelessWidget {
  const _CappedWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppFrame.shellWidth - Space.screenH * 2,
      ),
      child: child,
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  /// 탭 아이콘. **선을 유지한다** — 채운 아이콘은 칩 안에서 너무 무거워지고,
  /// 선택 표시는 색으로 한다.
  static IconData _icon(AppTab tab) => switch (tab) {
    AppTab.home => Icons.today_outlined,
    AppTab.discover => Icons.explore_outlined,
    AppTab.trend => Icons.show_chart,
    AppTab.records => Icons.history,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.paper : t.faint;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon(tab), size: 21, color: color),
            const SizedBox(height: Space.xs + 1),
            Text(
              tab.label,
              style: AppType.sans(
                size: AppType.smallLabelSize,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
