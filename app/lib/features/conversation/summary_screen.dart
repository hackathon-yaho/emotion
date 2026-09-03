import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S02-1 대화 종료 요약
///
/// F2-05. `summary`는 null일 수 있고 그때는 요약 영역을 숨긴다 (§1-3).
/// **gapAvg는 표시하지 않는다** (design-system §7-7).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Main.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S02-1'),
          const SizedBox(height: Space.lg),
          Text(
            '대화 종료 요약',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '한 줄 요약 · 길이·턴 수 · 홈으로',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
