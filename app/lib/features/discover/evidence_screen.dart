import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S03-1 관찰 근거
///
/// F7-07. **`turns` 길이와 `evidence.occurrences`가 같아야 한다** — 다르면
/// 계약 위반이며 §1.4 "evidence 불일치 0건" 지표 실패다.
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/Evidence.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class EvidenceScreen extends StatelessWidget {
  const EvidenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S03-1'),
          const SizedBox(height: Space.lg),
          Text(
            '관찰 근거',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '관찰 문장 · 수치 3종 · 근거 턴 목록(valence 둘 다 + 갭)',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
