import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S06 설정
///
/// F1-03 로그아웃 · F1-04 탈퇴 · F10-03 전량 삭제 · F10-04 고지 재열람 ·
/// F11-01 데모 모드.
///
/// 탈퇴 확인 시트는 **유예 없이 되돌릴 수 없음**을 정확히 말한다 (F1-04).
/// 파괴적 동작에 `care` 색을 쓰지 않는다 — care는 S07 전용 (§4).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Settings.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S06'),
          const SizedBox(height: Space.lg),
          Text(
            '설정',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '테마 · 안내 재열람 · 데모 모드 · 로그아웃 · 탈퇴',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
