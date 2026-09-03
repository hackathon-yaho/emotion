import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/typography.dart';

/// 작은 라벨 — 11px, 자간 0.14em, faint (design-system §3).
class SmallLabel extends StatelessWidget {
  const SmallLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppType.sans(
        size: AppType.smallLabelSize,
        color: context.tokens.faint,
        height: 1.4,
        letterSpacing: AppType.smallLabelSpacing,
      ),
    );
  }
}
