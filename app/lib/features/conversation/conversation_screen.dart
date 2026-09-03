import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S02 대화
///
/// F2-02 EVI 연결 · F2-03 세션 길이 · F2-04 실패 처리 · F11-01 데모 모드.
///
/// **여기에 valence·갭 수치를 그리지 않는다** (FR-031). 감정에 반응하는
/// 색도 쓰지 않는다 — 두 링은 색이 고정이고 간격·크기·투명도만 변한다
/// (FR-030). demoMode == true일 때만 예외.
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Conversation.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S02'),
          const SizedBox(height: Space.lg),
          Text(
            '대화',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '어긋난 두 링 · 상태 라벨 · 사용자 발화 자막 · 마치기',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
