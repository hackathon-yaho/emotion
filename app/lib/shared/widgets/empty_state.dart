import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// 빈 상태.
///
/// **명조를 쓰지 않는다** — 명조는 실제로 발견된 문장에만 쓰는 서체다. 빈
/// 상태가 명조면 "발견인 척"이 된다 (design-system §7-11). 억지 문구를 만들지
/// 않고 조건을 정직하게 말한다 (FR-052).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.detail});

  final String message;

  /// 조건을 설명하는 보조 문장 (예: 발견의 3회·1.5배 기준).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppType.sans(size: AppType.bodySize, color: t.muted),
        ),
        if (detail != null) ...[
          const SizedBox(height: Space.xl - Space.xs),
          Text(
            detail!,
            style: AppType.sans(
              size: AppType.captionSizeLg,
              color: t.faint,
              height: 1.75,
            ),
          ),
        ],
      ],
    );
  }
}
