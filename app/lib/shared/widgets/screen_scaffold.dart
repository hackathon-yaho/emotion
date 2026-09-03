import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// 화면 공통 뼈대 — 배경, 좌우 여백 24, 상단 안전영역.
///
/// **가짜 상태바를 그리지 않는다.** 실제 기기의 상태바가 위에 올라오므로
/// 그 자리는 비워 둔다.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.topPadding = 44,
    this.horizontal = Space.screenH,
  });

  final Widget child;
  final double topPadding;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    // Material 조상이 없으면 Flutter가 글자에 노란 밑줄을 그린다.
    // 잉크·텍스트 선택도 여기에 걸린다.
    return Material(
      color: context.tokens.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontal,
            right: horizontal,
            top: topPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
