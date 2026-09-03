import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S05 기록
///
/// F9-04. 항목에 `tags`·`gapAvg`를 표시한다 (design-system §7-8).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Main.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S05'),
          const SizedBox(height: Space.lg),
          Text(
            '기록',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '날짜 · 요약 · 길이·턴 · 갭 · 태그',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
