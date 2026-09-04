import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/confirm_sheet.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';

/// S06 설정.
///
/// F1-03 로그아웃 · F1-04 탈퇴 · F10-03 전량 삭제 · F10-04 고지 재열람 ·
/// F11-01 데모 모드.
///
/// 탈퇴 확인 시트는 **유예 없이 되돌릴 수 없음**을 정확히 말한다 (F1-04).
/// **파괴적 동작에 `care` 색을 쓰지 않는다** — care는 S07 전용이다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _demoMode = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mode = ref.watch(themeModeProvider);

    return ScreenScaffold(
      topPadding: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: Space.tapMin,
              height: Space.tapMin,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.chevron_left, size: 24, color: t.muted),
              ),
            ),
          ),
          const SizedBox(height: Space.xl - Space.xs),
          Text(
            '설정',
            style: AppType.serif(size: 26, color: t.paper),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Space.xxl),
                  const SmallLabel('화면'),
                  const SizedBox(height: Space.xs),
                  const Hairline(),
                  _Row(
                    label: '테마',
                    value: switch (mode) {
                      ThemeMode.system => '시스템 설정',
                      ThemeMode.dark => '어둡게',
                      ThemeMode.light => '밝게',
                    },
                    onTap: () => _cycleTheme(mode),
                  ),
                  const Hairline(),

                  const SizedBox(height: Space.xxl - Space.xs),
                  const SmallLabel('안내'),
                  const SizedBox(height: Space.xs),
                  const Hairline(),
                  // F1-05 고지 재열람 — 온보딩 3항을 다시 본다.
                  _Row(label: '처음 안내 다시 보기', onTap: () {}),
                  const Hairline(),
                  _Row(label: '목소리·기록 처리 방식', onTap: () {}),
                  const Hairline(),
                  const SizedBox(height: Space.md),
                  Text(
                    '목소리 원본은 저장하지 않습니다. 발화 텍스트는 암호화되어 보관되고, '
                    '카카오 계정 정보는 감정 기록과 분리되어 있습니다.',
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.faint,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: Space.xxl - Space.xs),
                  const SmallLabel('시연'),
                  const SizedBox(height: Space.xs),
                  const Hairline(),
                  _ToggleRow(
                    label: '데모 모드',
                    value: _demoMode,
                    onChanged: (v) => setState(() => _demoMode = v),
                  ),
                  const Hairline(),
                  const SizedBox(height: Space.md),
                  Text(
                    '대화 중 화면에 측정값을 표시합니다. 평소에는 꺼두세요.',
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.faint,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: Space.xxl - Space.xs),
                  const Hairline(),
                  _ToggleRow(
                    label: '샘플 데이터',
                    value: ref.watch(dataModeProvider) == DataMode.sample,
                    onChanged: (v) => _setSampleMode(v),
                  ),
                  const Hairline(),
                  const SizedBox(height: Space.md),
                  Text(
                    'Hume·백엔드를 타지 않고 준비된 데이터로 화면을 봅니다. '
                    '실제 통화가 열리지 않아 요금이 발생하지 않습니다. '
                    '주소에 ?sample=1 을 붙여도 같습니다.',
                    style: AppType.sans(
                      size: AppType.labelSize,
                      color: t.faint,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: Space.xxxl),
                  const Hairline(),
                  _Row(label: '로그아웃', onTap: _signOut, chevron: false),
                  const Hairline(),
                  // 파괴적 동작 — care 색을 쓰지 않고, 경고는 시트의 문장이 한다.
                  _Row(
                    label: '탈퇴',
                    quiet: true,
                    chevron: false,
                    onTap: _confirmLeave,
                  ),
                  const Hairline(),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleTheme(ThemeMode current) {
    final next = switch (current) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
    };
    ref.read(themeModeProvider.notifier).state = next;
  }

  /// 로그아웃 — 기기의 토큰만 지운다. **서버 데이터는 삭제하지 않는다** (F1-03).
  Future<void> _signOut() async {
    await ref.read(appSessionProvider).signOut();
    if (mounted) context.go(Routes.onboarding);
  }

  /// 탈퇴 — 유예 없이 전량 삭제 (F1-04 · F10-03).
  Future<void> _confirmLeave() async {
    final t = context.tokens;
    final ok = await showConfirmSheet(
      context,
      title: '계정을 지울까요?',
      confirmLabel: '모두 지우고 탈퇴',
      body: [
        const TextSpan(text: '대화 12건과 발견 3건이 지금 바로 모두 지워집니다.\n\n'),
        TextSpan(
          text: '유예 기간이 없고 되돌릴 수 없습니다.',
          style: TextStyle(color: t.paper),
        ),
        const TextSpan(text: ' 같은 카카오 계정으로 다시 시작하면 새 사용자가 됩니다.'),
      ],
    );
    if (!ok) return;
    // **서버가 지운 뒤에 기기를 비운다.** 순서를 뒤집으면 토큰이 없어져
    // 삭제 요청을 다시 보낼 수도 없다.
    //
    // `kakaoAuthCode`를 함께 보내면 백엔드가 카카오 연결까지 끊는다
    // (v1.6 §2-3). 지금은 인가 코드를 받아오는 흐름이 없어 보내지 않는다 —
    // 그래도 응답은 204이고 데이터는 지워진다.
    try {
      await ref.read(journalRepositoryProvider).deleteAccount();
    } on Object {
      // 실패하면 기기를 비우지 않는다 — 서버에 남은 데이터를 지울 방법이
      // 사라지기 때문이다.
      if (mounted) _showDeleteFailed();
      return;
    }
    await ref.read(appSessionProvider).reset();
    if (mounted) context.go(Routes.onboarding);
  }

  void _showDeleteFailed() {
    final t = context.tokens;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.lift,
        content: Text(
          '지금은 지울 수 없습니다. 잠시 후 다시 시도해 주세요.',
          style: AppType.sans(size: AppType.captionSize, color: t.paper),
        ),
      ),
    );
  }

  /// 샘플 모드 전환 — **불러온 데이터를 전부 버린다.**
  ///
  /// 출처가 바뀌었는데 캐시가 남으면 실제 데이터와 샘플이 한 화면에서
  /// 섞인다. 그게 가장 위험한 상태다.
  void _setSampleMode(bool on) {
    ref.read(dataModeProvider.notifier).state =
        on ? DataMode.sample : DataMode.live;
    ref.invalidate(meProvider);
    ref.invalidate(observationsProvider);
    ref.invalidate(sessionsProvider);
    ref.invalidate(trendProvider);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.onTap,
    this.quiet = false,
    this.chevron = true,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool quiet;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.sans(
                  size: AppType.bodySize,
                  color: quiet ? t.muted : t.paper,
                  height: 1.2,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppType.sans(
                  size: AppType.captionSizeLg,
                  color: t.muted,
                  height: 1.2,
                ),
              )
            else if (chevron)
              Icon(Icons.arrow_forward, size: 13, color: t.faint),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.sans(
                  size: AppType.bodySize,
                  color: t.paper,
                  height: 1.2,
                ),
              ),
            ),
            Container(
              width: 44,
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                border: Border.all(color: value ? t.accent : t.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? t.accent : t.faint,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
