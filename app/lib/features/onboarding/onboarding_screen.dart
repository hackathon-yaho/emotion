import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S00 진입 · 로그인
///
/// F1-01 카카오 로그인 · F1-05 온보딩 고지 3항 · F10-04 프라이버시 고지.
/// **동의 없이 대화 화면으로 진입할 수 없다** (F1-05 수용 기준).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Onboarding.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S00'),
          const SizedBox(height: Space.lg),
          Text(
            '진입 · 로그인',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '카카오 버튼은 브랜드 규격(#FEE500)을 따르고 공식 애셋으로 교체한다',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
