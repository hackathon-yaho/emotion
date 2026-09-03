import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S03 발견
///
/// F7-06 관찰 조회 · F7-08 피드백(P1).
/// 관찰이 0건이면 안내 문구만 띄우고 **가짜 관찰을 만들지 않는다** (FR-052).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Main.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S03'),
          const SizedBox(height: Space.lg),
          Text(
            '발견',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '관찰 목록 · evidence · 근거 보기 · 맞아요/아니에요',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
