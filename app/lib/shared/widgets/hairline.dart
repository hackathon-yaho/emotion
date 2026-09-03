import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 헤어라인. **카드를 쓰지 않는 언어에서 구획을 담당하는 유일한 선**이다
/// (design-system §1).
class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.tokens.line);
}
