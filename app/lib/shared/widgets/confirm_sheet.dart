import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'outline_button.dart';

/// 파괴적 동작 확인 시트 (탈퇴 · 대화 삭제).
///
/// **`care` 색을 쓰지 않는다** — care는 S07 전용이다(design-system §4).
/// 경고는 **문장**이 하고, **안전한 선택(취소)을 채운 버튼**으로, 파괴적
/// 선택은 테두리만 둔 버튼으로 만든다 — 실수로 누르기 어렵게.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required List<InlineSpan> body,
  required String confirmLabel,
}) async {
  final t = context.tokens;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.lift,
    barrierColor: t.bg.withValues(alpha: 0.6),
    builder: (context) => _ConfirmBody(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
    ),
  );
  return result ?? false;
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final List<InlineSpan> body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: Space.screenH,
        right: Space.screenH,
        top: Space.xxl,
        bottom: Space.xxl + Space.xs + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppType.serif(size: AppType.titleSize, color: t.paper),
          ),
          const SizedBox(height: Space.xl - Space.xs),
          Text.rich(
            TextSpan(
              children: body,
              style: AppType.sans(
                size: AppType.captionSizeLg + 1,
                color: t.muted,
                height: 1.75,
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          FilledAction(
            label: '취소',
            height: 56,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: Space.sm + 2),
          OutlineAction(
            label: confirmLabel,
            height: 56,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
