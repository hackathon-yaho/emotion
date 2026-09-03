import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S01 오늘
///
/// F2-01 대화 시작 CTA · F7-06 최근 관찰 · F2-07 이어하기 제안.
/// 빈 상태가 도그푸딩 첫 며칠의 실제 화면이다 (spec 5-1 #4·#18).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Main.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S01'),
          const SizedBox(height: Space.lg),
          Text(
            '오늘',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '관찰 카드 · 지난 대화 · CTA · 이어하기 블록',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
