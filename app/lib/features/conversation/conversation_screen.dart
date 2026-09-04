import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_frame.dart';
import '../../shared/widgets/hairline.dart';
import '../../shared/widgets/outline_button.dart';
import '../../shared/widgets/ring_pair.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/small_label.dart';
import '../crisis/crisis_sheet.dart';

/// 대화 상태 — 실제로는 EVI 이벤트가 바꾼다.
enum TalkState {
  connecting,
  resumed,
  listening,
  speaking,
  quiet,
  nearEnd,
  micDenied,
  networkLost,
  cannotStart,
}

/// S02 대화.
///
/// F2-02 EVI 연결 · F2-03 세션 길이 · F2-04 실패 처리 · F11-01 데모 모드.
///
/// **여기에 valence·갭 수치를 그리지 않는다** (FR-031). 두 링은 **색이 고정**이고
/// 간격·크기·투명도만 상태에 반응한다 — 색이 감정에 따라 변하면 사용자가
/// "화면이 어두워졌네"로 읽어 사실상 갭 노출이 된다(FR-030).
/// `demoMode == true`일 때만 예외다.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    this.initial = TalkState.listening,
    this.demoMode = false,
    this.showStatePicker = false,
    this.openCrisis = false,
  });

  final TalkState initial;
  final bool demoMode;

  /// 프로토타입 전환용 버튼. **실제 화면에는 없다.**
  final bool showStatePicker;

  /// 진입 직후 S07 위기 안내를 띄운다 — 시연·확인용.
  /// 실제로는 `GET /api/session/{id}/live`의 `crisisDetected` 전이가 띄운다.
  final bool openCrisis;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late TalkState _state = widget.initial;

  @override
  void initState() {
    super.initState();
    if (widget.openCrisis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onCrisisSignal(true);
      });
    }
  }

  /// S07은 `crisisDetected`의 **false → true 전이에서 한 번만** 띄운다
  /// (계약 §2-13). 폴링이 계속 true를 줘도 다시 띄우지 않는다.
  bool _crisisShown = false;

  _Ring get _ring => switch (_state) {
        TalkState.connecting =>
          const _Ring('연결하고 있습니다', size: 176, offset: 4, cool: 0.30, warm: 0.20),
        TalkState.resumed => const _Ring(
            '이어서 듣고 있습니다',
            size: 200,
            offset: 8,
            cool: 0.85,
            warm: 0.60,
            sub: '중단된 대화를 이어갑니다 · 남은 시간 4분 42초',
          ),
        TalkState.listening => const _Ring(
            '듣고 있습니다',
            size: 200,
            offset: 8,
            cool: 0.85,
            warm: 0.60,
            caption: '오늘 완전 괜찮았어요',
          ),
        TalkState.speaking =>
          const _Ring('말하고 있습니다', size: 168, offset: 3, cool: 0.50, warm: 0.35),
        TalkState.quiet =>
          const _Ring('듣고 있습니다', size: 184, offset: 5, cool: 0.50, warm: 0.32),
        TalkState.nearEnd => const _Ring(
            '듣고 있습니다',
            size: 196,
            offset: 7,
            cool: 0.80,
            warm: 0.55,
            caption: '그래서 좀 지치더라고요',
            nearEnd: true,
          ),
        TalkState.micDenied => const _Ring(
            '마이크가 꺼져 있습니다',
            size: 160,
            offset: 2,
            cool: 0.16,
            warm: 0.12,
            error: '마이크를 사용할 수 없습니다. 브라우저 설정에서 이 사이트의 마이크를 허용해 주세요.',
            cta: '설정 열기',
          ),
        TalkState.networkLost => const _Ring(
            '연결이 끊어졌습니다',
            size: 160,
            offset: 2,
            cool: 0.16,
            warm: 0.12,
            error: '연결이 끊어졌습니다. 다시 연결해 볼까요?',
            cta: '다시 연결',
          ),
        TalkState.cannotStart => const _Ring(
            '시작할 수 없습니다',
            size: 160,
            offset: 2,
            cool: 0.16,
            warm: 0.12,
            error: '지금은 대화를 시작할 수 없습니다. 잠시 후 다시 시도해 주세요.',
            cta: '다시 시도',
          ),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => _body(
        context,
        // §2-1 예외 — 데모 수치는 좁은 화면에서 본문 아래, 넓은 화면에서
        // 셸 오른쪽 패널로 간다.
        sidePanel: widget.demoMode && AppFrame.hasSidePanel(c.maxWidth),
      ),
    );
  }

  Widget _body(BuildContext context, {required bool sidePanel}) {
    final t = context.tokens;
    final r = _ring;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _BackButton(onTap: () => context.pop()),
            const Spacer(),
            if (widget.demoMode)
              Text(
                'DEMO',
                style: AppType.sans(
                  size: AppType.smallLabelSize,
                  color: t.accent,
                  height: 1.2,
                  letterSpacing: 0.16 * AppType.smallLabelSize,
                ),
              ),
          ],
        ),

        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RingPair(
                size: r.size,
                offset: r.offset,
                coolOpacity: r.cool,
                warmOpacity: r.warm,
              ),
              const SizedBox(height: 44),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: Column(
                  children: [
                    SmallLabel(r.label),
                    if (r.caption != null) ...[
                      const SizedBox(height: Space.lg + 2),
                      Text(
                        r.caption!,
                        textAlign: TextAlign.center,
                        style: AppType.serif(
                          size: 22,
                          color: t.paper,
                          height: 1.65,
                        ),
                      ),
                    ],
                    if (r.sub != null) ...[
                      const SizedBox(height: Space.lg + 2),
                      Text(
                        r.sub!,
                        textAlign: TextAlign.center,
                        style: AppType.sans(
                          size: AppType.captionSize,
                          color: t.faint,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (r.error != null) ...[
                      const SizedBox(height: Space.lg + 2),
                      Text(
                        r.error!,
                        textAlign: TextAlign.center,
                        style: AppType.sans(
                          size: AppType.bodySize,
                          color: t.muted,
                          height: 1.75,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
        ),

        if (widget.demoMode && !sidePanel) const _DemoPanel(),

        if (r.nearEnd)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                '잠시 뒤 오늘 대화가 마무리됩니다',
                textAlign: TextAlign.center,
                style: AppType.sans(
                  size: AppType.captionSize,
                  color: t.faint,
                  height: 1.5,
                ),
              ),
            ),
          ),

        if (widget.showStatePicker) _StatePicker(
          current: _state,
          onPick: (s) => setState(() => _state = s),
        ),

        if (r.cta == null)
          OutlineAction(
            label: '대화 마치기',
            height: 56,
            onPressed: () => context.go(Routes.summary),
          )
        else
          FilledAction(label: r.cta!, height: 56, onPressed: () {}),
        const SizedBox(height: 40),
      ],
    );

    return ScreenScaffold(
      topPadding: 40,
      child: sidePanel
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: main),
                const SizedBox(width: Space.xl),
                const SizedBox(
                  width: AppFrame.demoPanelWidth,
                  child: _DemoPanel(side: true),
                ),
              ],
            )
          : main,
    );
  }

  /// 위기 신호를 받았을 때 — **`false → true` 전이에서 한 번만** (계약 §2-13).
  /// 폴링이 계속 true를 줘도 다시 띄우지 않는다.
  void onCrisisSignal(bool detected) {
    if (!detected || _crisisShown) return;
    _crisisShown = true;
    showCrisisSheet(context);
  }
}

class _Ring {
  const _Ring(
    this.label, {
    required this.size,
    required this.offset,
    required this.cool,
    required this.warm,
    this.caption,
    this.sub,
    this.error,
    this.cta,
    this.nearEnd = false,
  });

  final String label;
  final double size;
  final double offset;
  final double cool;
  final double warm;
  final String? caption;
  final String? sub;
  final String? error;
  final String? cta;
  final bool nearEnd;
}

/// F11-01 데모 모드 — `demoMode == true`일 때만 수치를 노출한다.
class _DemoPanel extends StatelessWidget {
  const _DemoPanel({this.side = false});

  /// `true`면 셸 오른쪽 패널 (§2-1). `false`면 본문 아래 배지.
  final bool side;

  @override
  Widget build(BuildContext context) {
    const rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hairline(),
        _DemoRow(label: '말한 내용', value: '0.70'),
        Hairline(),
        _DemoRow(label: '목소리', value: '−0.62'),
        Hairline(),
        _DemoRow(label: '갭 · 트리거', value: '1.32 · 예', accent: true),
        Hairline(),
      ],
    );

    if (side) {
      return const Align(alignment: Alignment.center, child: rows);
    }
    return const Padding(
      padding: EdgeInsets.only(bottom: Space.xl - Space.xs),
      child: rows,
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SmallLabel(label),
          Text(
            value,
            style: AppType.sans(
              size: AppType.captionSize,
              color: accent ? t.accent : t.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePicker extends StatelessWidget {
  const _StatePicker({required this.current, required this.onPick});

  final TalkState current;
  final ValueChanged<TalkState> onPick;

  static const _labels = {
    TalkState.connecting: '연결 중',
    TalkState.resumed: '이어하기',
    TalkState.listening: '듣는 중',
    TalkState.speaking: '말하는 중',
    TalkState.quiet: '조용',
    TalkState.nearEnd: '마무리 임박',
    TalkState.micDenied: '마이크 거부',
    TalkState.networkLost: '네트워크 끊김',
    TalkState.cannotStart: '연결 불가',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmallLabel('상태 — 프로토타입 전환용'),
          const SizedBox(height: Space.sm + 2),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            childAspectRatio: 2.3,
            children: [
              for (final entry in _labels.entries)
                GestureDetector(
                  onTap: () => onPick(entry.key),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: entry.key == current ? t.accent : t.line,
                      ),
                      borderRadius: const BorderRadius.all(Radii.control),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: AppType.sans(
                        size: AppType.labelSize,
                        color: entry.key == current ? t.paper : t.faint,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: Space.tapMin,
        height: Space.tapMin,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.chevron_left, size: 24, color: t.muted),
        ),
      ),
    );
  }
}
