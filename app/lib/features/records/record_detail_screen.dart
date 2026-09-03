import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S05-1 대화 상세
///
/// F9-05 · F10-01 세션 삭제.
/// **갭 수치는 이 화면에서는 노출된다** — 대화 화면과 구분되는 지점이다
/// (FR-031). assistant 턴은 valence·gap이 전부 null이다.
///
/// 삭제 확인 시트는 **연쇄 무효화를 미리 말한다** (FR-081).
///
/// 골격 단계의 자리표시 화면이다. 확정된 디자인은 `app/design/SessionDetail.dc.html`에 있고,
/// 그것을 이 파일로 옮기는 것이 다음 작업이다.
class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('S05-1'),
          const SizedBox(height: Space.lg),
          Text(
            '대화 상세',
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.lg),
          Text(
            '턴 목록 · 사용자 턴의 valence·갭 · 삭제 확인 시트',
            style: AppType.sans(size: AppType.captionSizeLg, color: t.faint),
          ),
        ],
      ),
    );
  }
}
