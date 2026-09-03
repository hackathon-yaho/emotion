import 'package:flutter/material.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 앱 셸 — 하단 탭 4개.
///
/// **텍스트 + 밑줄이고 아이콘이 없다** (design-system §1: 활자가 일한다).
/// 레이아웃은 모바일 폭 기준이고, 넓은 화면에서는 셸을 중앙에 고정한다 (§2).
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

  /// 앱 셸 최대 폭 (§2). 420을 넘기면 한 손 UI가 늘어져 보인다.
  static const maxWidth = 420.0;

  /// 분기점 하나. `< 600` 전폭 / `>= 600` 중앙 고정 (§2).
  static const breakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shell = Column(
      children: [
        Expanded(child: child),
        _TabBar(current: currentTab, onSelected: onTabSelected),
      ],
    );

    return Material(
      color: t.bg,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < breakpoint) return shell;
          return Center(
            child: SizedBox(width: maxWidth, child: shell),
          );
        },
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelected});

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: Space.screenH,
        right: Space.screenH,
        top: Space.xxl - Space.xs,
        bottom: Space.xxl + Space.xs + bottom,
      ),
      child: Row(
        children: [
          for (final tab in AppTab.values) ...[
            if (tab != AppTab.values.first) const SizedBox(width: 26),
            _TabItem(
              label: tab.label,
              selected: tab == current,
              onTap: () => onSelected(tab),
              paper: t.paper,
              faint: t.faint,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.paper,
    required this.faint,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color paper;
  final Color faint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: Space.tapMin,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppType.sans(
                  size: AppType.captionSize,
                  color: selected ? paper : faint,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: Space.sm),
              Container(
                height: 1,
                width: label.length * AppType.captionSize,
                color: selected ? paper : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
