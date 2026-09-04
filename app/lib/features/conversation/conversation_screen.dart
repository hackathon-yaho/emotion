import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/live_models.dart';
import '../../core/models/session_models.dart';
import '../../core/providers.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_clock.dart';
import '../../core/voice/evi_event.dart';
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
class ConversationScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  late TalkState _state = widget.initial;

  /// 방금 들은 사용자 발화 — 잠깐만 띄운다 (design-system §6-1).
  String? _heard;
  Timer? _heardTimer;
  StreamSubscription<EviEvent>? _eviSub;

  /// F2-03 — 하드컷 60초 전 표시 · 하드컷 자동 종료.
  Timer? _nearEndTimer;
  Timer? _hardCutTimer;

  @override
  void initState() {
    super.initState();
    if (widget.openCrisis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onCrisisSignal(true);
      });
    }
    // 상태를 고정해 보는 프로토타입 모드에서는 세션을 열지 않는다.
    if (!widget.showStatePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  /// 세션 시작 (§2-4) 또는 이어하기 (§2-5-1) → **EVI 연결** (F2-02).
  ///
  /// 순서가 중요하다 — 세션을 먼저 세우고 그 응답의 단기 토큰으로 소켓을
  /// 연다. 앱에는 Hume 키가 없다 (FR-013).
  ///
  /// **샘플 모드에서는 소켓을 열지 않는다.** 토큰이 가짜라 붙지도 못하지만,
  /// 시도 자체를 하지 않아야 실수로 실제 통화가 열릴 여지가 없다.
  Future<void> _open() async {
    final repo = ref.read(journalRepositoryProvider);
    ref.read(inConversationProvider.notifier).state = true;
    setState(() => _state = TalkState.connecting);
    try {
      final open = await repo.me().then((m) => m.openSession);
      final SessionStart session;
      if (open != null) {
        final r = await repo.resumeSession(open.sessionId);
        if (!mounted) return;
        // 이어하기는 새 7분을 주지 않는다 (NFR-06) — 남은 시간을 그대로 쓴다.
        session = _asStart(r);
        // 이전 대화 맥락은 이 값으로 복원된다. 백엔드가 아직 null만 주므로
        // (`request/app/chat-group-id.md`) 같은 세션 안에서 받은 값을 쓴다.
        ref.read(chatGroupIdProvider.notifier).state =
            r.resumedChatGroupId.isEmpty ? null : r.resumedChatGroupId;
      } else {
        session = await repo.startSession();
        if (!mounted) return;
      }
      ref.read(activeSessionProvider.notifier).state = session;
      setState(() => _state = open != null
          ? TalkState.resumed
          : TalkState.listening);
      _startClock(session.hardCutSec);

      if (ref.read(dataModeProvider) == DataMode.sample) return;
      await _connectVoice(session);
    } catch (_) {
      if (!mounted) return;
      // 원인별 문구는 F2-04 — 여기서는 "시작할 수 없다"로 모은다.
      setState(() => _state = TalkState.cannotStart);
    }
  }

  /// EVI 소켓을 열고 사건을 화면 상태로 옮긴다.
  Future<void> _connectVoice(SessionStart session) async {
    final evi = ref.read(eviServiceProvider);
    _eviSub?.cancel();
    _eviSub = evi.events.listen(_onEvi);
    await evi.start(
      accessToken: session.humeAccessToken,
      configId: session.humeConfigId,
      sessionId: session.sessionId,
      resumedChatGroupId: ref.read(chatGroupIdProvider),
    );
  }

  /// EVI 사건 → 화면.
  ///
  /// **자막을 쌓지 않는다** (design-system §6-1) — 사용자 발화만 잠깐 띄우고
  /// AI 발화는 텍스트로 그리지 않는다. 소리로 듣는 것을 글로 또 보여주면
  /// 채팅앱이 된다.
  void _onEvi(EviEvent e) {
    if (!mounted) return;
    switch (e) {
      case EviConnected(:final chatGroupId):
        // F2-07의 원천. 백엔드에 넘길 엔드포인트는 아직 없다.
        if (chatGroupId != null) {
          ref.read(chatGroupIdProvider.notifier).state = chatGroupId;
        }
        setState(() => _state = TalkState.listening);

      case EviUserSpoke(:final text):
        // 잠깐만 보여준다 — 다음 발화가 오거나 3초가 지나면 사라진다.
        _showHeard(text);

      case EviAssistantSpoke():
        setState(() => _state = TalkState.speaking);

      case EviAssistantDone():
        setState(() => _state = TalkState.listening);

      case EviUserInterruption():
        setState(() => _state = TalkState.listening);

      case EviClosed():
        // 대화 중 끊긴 것이면 알린다. 우리가 끊은 경우는 이미 화면을 떠났다.
        setState(() => _state = TalkState.networkLost);

      case EviFailed(:final reason):
        setState(() => _state = switch (reason) {
              EviFailure.micDenied => TalkState.micDenied,
              EviFailure.network => TalkState.networkLost,
              EviFailure.auth => TalkState.cannotStart,
              EviFailure.unknown => TalkState.cannotStart,
            });
    }
  }

  /// 방금 들은 말을 잠깐 띄운다 (§6-1 절충안).
  void _showHeard(String text) {
    _heardTimer?.cancel();
    setState(() {
      _heard = text;
      _state = TalkState.listening;
    });
    _heardTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _heard = null);
    });
  }

  /// F2-03 — 하드컷을 향한 두 개의 타이머.
  ///
  /// **소프트 랩(5분)에는 아무것도 하지 않는다** — AI가 말로 유도하므로
  /// UI가 개입하면 두 번 재촉하는 셈이다 (§7 결정 1).
  void _startClock(int hardCutSec) {
    _nearEndTimer?.cancel();
    _hardCutTimer?.cancel();
    _nearEndTimer = Timer(SessionClock.nearEndAfter(hardCutSec), () {
      // 오류 상태를 덮어쓰지 않는다 — 연결이 끊긴 화면에 "마무리됩니다"가
      // 뜨면 무슨 일이 일어난 건지 알 수 없다.
      if (mounted && _isTalking) setState(() => _state = TalkState.nearEnd);
    });
    _hardCutTimer = Timer(SessionClock.hardCutAfter(hardCutSec), () {
      if (mounted) _end(reason: SessionClock.reasonHardCut);
    });
  }

  /// 데모 패널이 보여주는 **실측값**.
  ///
  /// `demoMode == false`인 세션에서는 서버가 `turns: []`를 준다 — 그건
  /// "볼 권한이 없다"이지 "값이 없다"가 아니다 (§2-13). 그래서 비어 있으면
  /// 패널이 값 대신 `—`를 쓴다. **샘플 수치를 대신 채우지 않는다** — 그러면
  /// 시연에서 가짜 숫자를 읽게 된다.
  LiveTurn? get _lastTurn =>
      ref.watch(liveSignalProvider).valueOrNull?.turns.lastOrNull;

  /// 대화가 진행 중인 상태인지 — 실패·거부 상태에서는 시계가 화면을 건드리지
  /// 않는다.
  bool get _isTalking => switch (_state) {
        TalkState.listening ||
        TalkState.speaking ||
        TalkState.quiet ||
        TalkState.resumed =>
          true,
        _ => false,
      };

  /// 이어하기 응답을 세션 값으로 맞춘다 — 폴링 간격은 §2-5-1에 없어 기본 2초.
  SessionStart _asStart(SessionResume r) => SessionStart(
        sessionId: r.sessionId,
        humeAccessToken: r.humeAccessToken,
        humeTokenExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
        thresholdMode: r.thresholdMode,
        gapThreshold: r.gapThreshold,
        softWrapSec: 300,
        hardCutSec: r.remainingSec,
        demoMode: r.demoMode,
        humeConfigId: r.humeConfigId,
        livePollIntervalSec: 2,
      );

  /// 대화 마치기 (§2-6) — 요약을 들고 S02-1로 간다.
  Future<void> _end({String reason = SessionClock.reasonUserEnd}) async {
    final session = ref.read(activeSessionProvider);
    _nearEndTimer?.cancel();
    _hardCutTimer?.cancel();
    ref.read(inConversationProvider.notifier).state = false;
    // **마이크를 먼저 끈다.** 종료 호출이 느려도 그동안 소리가 나가지 않는다.
    await _eviSub?.cancel();
    _eviSub = null;
    if (ref.read(dataModeProvider) == DataMode.live) {
      await ref.read(eviServiceProvider).stop();
    }
    if (session == null) {
      if (mounted) context.go(Routes.summary);
      return;
    }
    try {
      final end = await ref
          .read(journalRepositoryProvider)
          .endSession(session.sessionId, endReason: reason);
      ref.read(lastSessionEndProvider.notifier).state = end;
    } catch (_) {
      // 종료 호출이 실패해도 화면은 넘긴다 — 대화는 이미 끝났고, 서버는
      // 타임아웃으로 정리한다 (§2-6 `endReason: timeout`).
    }
    ref.read(activeSessionProvider.notifier).state = null;

    // F1-02 — 대화 중에 JWT가 만료됐다면 **여기서** 내보낸다. 대화를 끊지
    // 않기로 미뤄둔 처리다.
    if (ref.read(pendingSignOutProvider)) {
      ref.read(pendingSignOutProvider.notifier).state = false;
      await ref.read(appSessionProvider).signOut();
      return; // 게이트가 S00으로 보낸다 — 요약을 보여줄 자격이 없다.
    }

    // 기록·추세가 한 건 늘었다.
    ref.invalidate(sessionsProvider);
    ref.invalidate(trendProvider);
    ref.invalidate(meProvider);
    if (mounted) context.go(Routes.summary);
  }

  @override
  void dispose() {
    _heardTimer?.cancel();
    _nearEndTimer?.cancel();
    _hardCutTimer?.cancel();
    _eviSub?.cancel();
    // 화면을 벗어나면 폴링이 멈추도록 세션을 놓는다.
    ref.read(inConversationProvider.notifier).state = false;
    super.dispose();
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
        sidePanel: _showDemo && AppFrame.hasSidePanel(c.maxWidth),
      ),
    );
  }

  /// 수치를 노출해도 되는지 — **FR-031의 유일한 예외**다 (F11-01).
  ///
  /// 셋 중 하나라도 켜져 있으면 노출한다: 주소의 `?demo=1`(시연용),
  /// S06의 저장된 설정, 그리고 **서버가 그 세션을 데모로 표시한 경우**
  /// (§2-4 `demoMode`) — 서버가 데모여야 `live`의 `turns`가 실제로 채워진다.
  bool get _showDemo =>
      widget.demoMode ||
      ref.watch(demoModeProvider) ||
      (ref.watch(activeSessionProvider)?.demoMode ?? false);

  Widget _body(BuildContext context, {required bool sidePanel}) {
    final t = context.tokens;
    final r = _ring;

    // 위기 신호 — 전이에서 한 번만 (§2-13).
    ref.listen(liveSignalProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null) onCrisisSignal(v.crisisDetected);
    });

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
                    // 실제 발화가 들어오면 대본 문구 대신 그것을 띄운다.
                    // **AI 발화는 여기 오지 않는다** — 소리로만 듣는다 (§6-1).
                    if ((_heard ?? r.caption) != null) ...[
                      const SizedBox(height: Space.lg + 2),
                      Text(
                        _heard ?? r.caption!,
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

        if (_showDemo && !sidePanel) _DemoPanel(turn: _lastTurn),

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
          OutlineAction(label: '대화 마치기', height: 56, onPressed: _end)
        else
          FilledAction(label: r.cta!, height: 56, onPressed: _open),
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
                SizedBox(
                  width: AppFrame.demoPanelWidth,
                  child: _DemoPanel(turn: _lastTurn, side: true),
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

/// F11-01 데모 모드 — 노출 판정은 [_ConversationScreenState._showDemo]가 한다.
///
/// **수치는 `GET /api/session/{id}/live`가 준 실측값이다** (§2-13). 값이 없으면
/// `—`를 쓴다 — 샘플 숫자를 대신 채우면 시연에서 가짜를 읽는다.
class _DemoPanel extends StatelessWidget {
  const _DemoPanel({required this.turn, this.side = false});

  final LiveTurn? turn;

  /// `true`면 셸 오른쪽 패널 (§2-1). `false`면 본문 아래 배지.
  final bool side;

  static String _v(double? value) =>
      value == null ? '—' : value.toStringAsFixed(2).replaceFirst('-', '−');

  @override
  Widget build(BuildContext context) {
    final t = turn;
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Hairline(),
        _DemoRow(label: '말한 내용', value: _v(t?.textValence)),
        const Hairline(),
        _DemoRow(label: '목소리', value: _v(t?.voiceValence)),
        const Hairline(),
        _DemoRow(
          label: '갭 · 트리거',
          value: t == null
              ? '—'
              : '${_v(t.gap)} · ${t.gapTriggered ? '예' : '아니오'}',
          accent: true,
        ),
        const Hairline(),
      ],
    );

    if (side) return Align(alignment: Alignment.center, child: rows);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl - Space.xs),
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
