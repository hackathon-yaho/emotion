import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/small_label.dart';

/// S07 위기 안내를 띄운다.
///
/// **대화를 끊지 않는다** — 오버레이 시트일 뿐이고, 뒤에서 대화가 계속된다
/// (FR-033). 가장 필요한 순간에 사용자를 버리는 설계가 되기 때문이다.
Future<void> showCrisisSheet(BuildContext context) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: t.bg.withValues(alpha: 0.55),
    builder: (_) => const CrisisSheet(),
  );
}

/// S07 위기 안내 (F4-04).
///
/// **경고 빨강을 쓰지 않는다** (design-system §4-1) — 빨강은 "당신은 위험한
/// 상태입니다"라고 단정하는 셈이다. 이 제품은 절대 감정을 단정하지 않고
/// (FR-022) 곁에 있는 설계이므로, 시트는 경고창이 아니라 손을 내미는 카드다.
///
/// **웹 배포라 데스크톱에서 `tel:`이 동작하지 않는다** (§4-2) — 번호를 크게
/// 표시하고 복사 버튼을 함께 둔다.
class CrisisSheet extends StatelessWidget {
  const CrisisSheet({super.key});

  /// 자살예방 상담전화 — 2024-01-01부터 통합 운영되는 24시간 번호.
  static const hotline = '109';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 뒤에는 **실제 대화 화면이 그대로 있다** — 시트가 장식용 링을 또
        // 그리지 않는다. 대화가 끊기지 않았음을 문구로만 말한다 (FR-033).
        Padding(
          padding: const EdgeInsets.only(bottom: Space.xxl - Space.xs),
          child: Text(
            '대화는 계속되고 있습니다',
            style: AppType.sans(
              size: AppType.captionSizeLg,
              color: t.muted,
              height: 1.2,
            ),
          ),
        ),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.lift,
            border: Border(top: BorderSide(color: t.care)),
            borderRadius: const BorderRadius.vertical(top: Radii.sheet),
          ),
          padding: EdgeInsets.only(
            left: Space.screenH,
            right: Space.screenH,
            top: Space.xxl - Space.xs,
            bottom: Space.xxl + Space.xs +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration:
                        BoxDecoration(color: t.care, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(
                    '전문 상담·치료를 대체하지 않습니다',
                    style: AppType.sans(
                      size: AppType.smallLabelSize,
                      color: t.muted,
                      height: 1.2,
                      letterSpacing: 0.08 * AppType.smallLabelSize,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(
                '혼자 견디지 않으셔도 됩니다.\n지금 이야기할 사람이 있습니다.',
                style: AppType.serif(size: AppType.titleSize, color: t.paper),
              ),
              const SizedBox(height: Space.xxl - Space.xs),
              const SmallLabel('자살예방 상담전화 · 24시간'),
              const SizedBox(height: Space.sm + 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hotline,
                    style: AppType.serif(
                      size: 52,
                      color: t.paper,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: Space.md + 2),
                  Text(
                    '무료 · 익명',
                    style: AppType.sans(
                      size: AppType.captionSize,
                      color: t.muted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxl - Space.xs),
              Row(
                children: [
                  Expanded(
                    child: FilledAction(
                      label: '전화 연결',
                      height: 56,
                      background: t.care,
                      foreground: t.onAccent,
                      // **데스크톱에서는 동작하지 않는다** — 웹 배포라
                      // `tel:`을 열 수 없고, 복사 버튼이 그 대비다
                      // (design-system §7 결정 3 · §4-3).
                      //
                      // 실패해도 조용히 넘긴다. 위기 안내 화면에서 오류
                      // 팝업을 띄우는 것이 가장 나쁜 선택이다.
                      onPressed: () => launchUrl(Uri.parse('tel:$hotline'))
                          .catchError((_) => false),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  SizedBox(
                    width: 112,
                    child: OutlineAction(
                      label: '복사',
                      height: 56,
                      onPressed: () =>
                          Clipboard.setData(const ClipboardData(text: hotline)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md + 2),
              Text(
                '컴퓨터에서는 전화가 걸리지 않습니다. 번호를 복사해 휴대폰으로 걸어 주세요.',
                style: AppType.sans(
                  size: AppType.labelSize,
                  color: t.faint,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: Space.xl - Space.xs),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: Text(
                      '대화로 돌아가기',
                      style: AppType.sans(
                        size: AppType.captionSizeLg + 1,
                        color: t.muted,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
