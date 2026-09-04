import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/kakao_button.dart';
import '../../shared/widgets/screen_scaffold.dart';

/// S00 진입 · 로그인.
///
/// F1-01 카카오 로그인 · F1-05 온보딩 고지 · F10-04 프라이버시 고지.
///
/// **동의 없이 대화 화면으로 진입할 수 없다** (F1-05 수용 기준) — 라우터
/// 가드가 막고, 여기서 동의가 기록된다.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return ScreenScaffold(
      topPadding: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 고지 배지 — S00과 S07에만 둔다 (spec §4).
          // 전 화면에 두면 세 화면째부터 배경으로 인식되어 읽히지 않는다.
          const _NoticeBadge('전문 상담·치료를 대체하지 않습니다'),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Text(
                    '말로 하루를\n이야기하면,\n말투에서 마음을 읽습니다.',
                    style: AppType.serif(
                      size: 30,
                      color: t.paper,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 44),
                  const _Notice(
                    index: '01',
                    lead: '목소리는 ',
                    strong: '분석 직후 삭제',
                    tail: '되고 어디에도 저장되지 않습니다.',
                  ),
                  const _Notice(
                    index: '02',
                    lead: '감정을 단정하지 않습니다. 말과 목소리가 다를 때 ',
                    strong: '되물을 뿐',
                    tail: '입니다.',
                  ),
                  const _Notice(
                    index: '03',
                    lead: '힘들 땐 ',
                    strong: '자살예방 상담전화 109',
                    tail: '로 24시간 연결됩니다.',
                  ),
                  const Hairline(),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),

          KakaoButton(
            onPressed: () async {
              // TODO(app): 카카오 SDK 로그인 → POST /api/auth/kakao.
              // 지금은 고지 동의만 기록하고 홈으로 보낸다.
              await ref.read(appSessionProvider).completeLogin('dev-token');
              if (context.mounted) context.go(Routes.home);
            },
          ),
          const SizedBox(height: Space.lg),
          Text(
            '시작하면 위 내용에 동의한 것으로 봅니다',
            textAlign: TextAlign.center,
            style: AppType.sans(
              size: AppType.smallLabelSize,
              color: t.faint,
              height: 1.7,
              letterSpacing: 0.04 * AppType.smallLabelSize,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _NoticeBadge extends StatelessWidget {
  const _NoticeBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: t.line),
        borderRadius: const BorderRadius.all(Radii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: t.muted, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.sm),
          Text(
            text,
            style: AppType.sans(
              size: AppType.smallLabelSize,
              color: t.muted,
              height: 1.2,
              letterSpacing: 0.08 * AppType.smallLabelSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.index,
    required this.lead,
    required this.strong,
    required this.tail,
  });

  final String index;
  final String lead;
  final String strong;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = AppType.sans(
      size: AppType.captionSizeLg + 1,
      color: t.muted,
      height: 1.7,
    );

    return Column(
      children: [
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl - Space.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    index,
                    style: AppType.sans(
                      size: AppType.smallLabelSize,
                      color: t.faint,
                      height: 1.4,
                      letterSpacing: AppType.smallLabelSpacing,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: lead),
                      TextSpan(text: strong, style: TextStyle(color: t.paper)),
                      TextSpan(text: tail),
                    ],
                    style: body,
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
