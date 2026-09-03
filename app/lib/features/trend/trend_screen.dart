import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S04 추세
///
/// F9-01 두 선 그래프 · F9-02 갭 구간 강조 · F9-03 이야기별 갭(P1).
///
/// 축은 **−1~+1 고정**이고 **기록이 없는 날은 선을 끊는다** (F9-01 수용 기준).
/// 축이 하나이므로 이중 축을 쓰지 않는다.
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/TrendWide.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class TrendScreen extends StatelessWidget {
  const TrendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S04'),
          const SizedBox(height: Space.lg),
          Text(
            '추세',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '두 선 · 음영 · 범례 · 기간 7·30·90일 · 이야기별 갭 막대',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
