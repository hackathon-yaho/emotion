import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 「두 겹」 — 갭이 실제 주제인 두 곳에만 쓴다 (design-system §1).
///
/// **그림자 한 겹으로 구현한다.** 같은 텍스트를 두 벌 겹치면 세로 오프셋이
/// 폰트 크기·행간마다 달라진다(3px 의도가 6px·4px로 어긋난 사고가 있었다).
/// 사본이 하나면 그 실패가 구조적으로 불가능하다.
class DoubledText extends StatelessWidget {
  const DoubledText(this.text, {super.key, this.size = 24, this.height = 1.4});

  final String text;
  final double size;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      style: AppType.serif(
        size: size,
        color: t.paper,
        height: height,
        shadows: Doubled.shadows(t.dblShadow),
      ),
    );
  }
}
