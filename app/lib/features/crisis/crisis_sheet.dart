import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S07 위기 안내
///
/// F4-04. **대화를 끊지 않는다** — 오버레이 시트일 뿐이다 (FR-033).
///
/// 경고 빨강을 쓰지 않는다 (§4-1). 웹 배포라 데스크톱에서 `tel:`이 동작하지
/// 않으므로 **번호를 크게 표시하고 복사 버튼을 함께** 둔다 (§4-2).
///
/// 트리거 경로가 아직 없다 — `docs/request/backend/live-turn-signal.md` (⏳).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Crisis.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class CrisisSheet extends StatelessWidget {
  const CrisisSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S07'),
          const SizedBox(height: Space.lg),
          Text(
            '위기 안내',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '109 번호 · 전화·복사 버튼 · 대화로 돌아가기',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
