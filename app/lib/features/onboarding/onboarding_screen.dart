import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/kakao_login.dart';
import '../../core/config/browser_url.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
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
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// 인가 코드를 교환하는 중 — 버튼을 두 번 누르지 못하게 한다. 코드는
  /// **1회용**이라 두 번 보내면 두 번째가 400이다 (§2-1).
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 카카오가 돌려보낸 직후라면 주소에 코드가 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishIfReturned());
  }

  /// ③ 복귀 처리 — 주소의 `?code=`를 JWT로 바꾼다.
  Future<void> _finishIfReturned() async {
    final here = Uri.base;
    if (KakaoLogin.deniedIn(here)) {
      // 사용자가 동의 화면에서 취소한 경우다. 오류로 다루지 않는다.
      clearQuery();
      return;
    }
    final code = KakaoLogin.codeFrom(here);
    if (code == null) return;

    setState(() => _busy = true);
    try {
      final auth = await ref.read(journalRepositoryProvider).authKakao(
            kakaoAuthCode: code,
            // **인가 때 쓴 것과 같은 값이어야 한다** — 서버가 대조한다.
            redirectUri: KakaoLogin.redirectUriFrom(here).toString(),
          );
      // ⑤ 먼저 지운다. 새로고침이 같은 코드를 다시 보내면 400이다.
      clearQuery();
      await ref.read(appSessionProvider).completeLogin(auth.jwt);
      if (mounted) context.go(Routes.home);
    } on ApiException catch (e) {
      clearQuery();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.isNetwork
              ? '연결이 되지 않습니다. 네트워크를 확인해 주세요.'
              : '로그인이 완료되지 않았습니다. 다시 시도해 주세요.';
        });
      }
    } on Object {
      clearQuery();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '로그인이 완료되지 않았습니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  /// ①② 인가 페이지로 보낸다.
  ///
  /// **샘플 모드에서는 카카오에 가지 않는다** — 백엔드도 없는 상태에서 화면을
  /// 보려는 모드이므로 그 자리에서 통과시킨다.
  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    if (ref.read(dataModeProvider) == DataMode.sample) {
      final auth = await ref.read(journalRepositoryProvider).authKakao(
            kakaoAuthCode: 'sample',
            redirectUri: KakaoLogin.redirectUriFrom(Uri.base).toString(),
          );
      await ref.read(appSessionProvider).completeLogin(auth.jwt);
      if (mounted) context.go(Routes.home);
      return;
    }

    final url = KakaoLogin.authorizeUrl(
      redirectUri: KakaoLogin.redirectUriFrom(Uri.base),
    );
    if (url == null) {
      // 키가 아직 없다. **조용히 실패하지 않는다** — 눌렀는데 아무 일도
      // 없으면 버그로 보인다.
      setState(() {
        _busy = false;
        _error = '아직 로그인을 켤 수 없습니다. 카카오 키가 등록되면 됩니다.';
      });
      return;
    }
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
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

          if (_error != null) ...[
            Text(
              _error!,
              style: AppType.sans(
                size: AppType.captionSize,
                color: t.muted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
          KakaoButton(onPressed: _busy ? null : _start),
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
