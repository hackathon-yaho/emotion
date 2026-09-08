import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/live_models.dart';
import '../../core/config/env.dart';
import '../../core/data/journal_repository.dart';
import '../../core/models/queue_models.dart';
import '../../core/models/session_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_clock.dart';
import '../../core/voice/evi_service.dart';
import '../../core/voice/speaker.dart';
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

/// 줄을 섰다는 내부 신호 — 오류가 아니다.
class _Queued implements Exception {
  const _Queued();
}

/// 대화 상태 — 실제로는 EVI 이벤트가 바꾼다.
// **링에 목업 발화를 넣지 않는다.** 디자인 프로토타입 때 넣은 "오늘 완전
// 괜찮았어요"가 실제 대화에서 계속 떠 있었다 (2026-09-06). 이 자리에는
// **실제로 들은 말만** 온다 (`_heard`).
enum TalkState {
  connecting,
  resumed,
  listening,

  /// 발화가 끝나고 첫 음성이 나오기 전 (F2-02, `request/app/conversation-latency.md`).
  ///
  /// **실측 p50 2.4초 · p95 3.2초다.** 그 사이 화면이 안 바뀌면 사용자는 앱이
  /// 멈췄다고 판단한다 — 감정 대화는 한 마디가 무거워서 침묵이 더 길게
  /// 느껴진다.
  thinking,

  speaking,

  /// 정원이 차서 줄을 서고 있다 (계약 v1.9 §2-14).
  ///
  /// **Hume 동시 접속 상한 때문이다** — Free 1 · Starter 5. 넘긴 연결은
  /// 기다리지 못하고 `E0700`으로 거절당하므로 순번은 우리 서버가 만든다.
  queued,
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

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with SingleTickerProviderStateMixin {
  late TalkState _state = widget.initial;

  /// 방금 들은 사용자 발화 — 잠깐만 띄운다 (design-system §6-1).
  String? _heard;
  Timer? _heardTimer;
  StreamSubscription<EviEvent>? _eviSub;

  /// F2-03 — 하드컷 60초 전 표시 · 하드컷 자동 종료.
  Timer? _nearEndTimer;
  Timer? _hardCutTimer;

  /// 「생각 중」이 길어졌는지. 실측 p95가 3.2초라 **그 위에서만** 한 줄 더
  /// 붙인다 — 정상 범위에서 문구가 뜨면 매 턴 사과하는 화면이 된다.
  static const _slowAfter = Duration(seconds: 4);
  bool _slowThinking = false;
  Timer? _slowTimer;

  /// 「생각 중」의 느린 숨 — **기다림을 링이 감당한다.**
  ///
  /// 별도 표시(점 세 개·스피너)를 두지 않는다. 이 화면의 유일한 그림이 두
  /// 링이고, 거기에 로딩 기호를 얹으면 조용한 언어가 깨진다.
  ///
  /// **생각 중일 때만 돈다.** 계속 돌리면 웹에서 매 프레임을 다시 그린다.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

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
      String? resumedChatGroupId;
      // **이어할 수 있는지 먼저 본다.** 30분 창이 지난 세션에 `resume`을 부르면
      // 409 `SESSION_NOT_RESUMABLE`이 오고, 그걸 "시작할 수 없습니다"로
      // 보여주면 사용자는 앱이 고장 난 줄 안다 — 실제로는 새로 시작하면 되는
      // 상황이다 (design-system §7 결정 14).
      if (open != null && open.isResumable) {
        final SessionResume r;
        try {
          r = await repo.resumeSession(open.sessionId);
        } on ApiException catch (e) {
          // 창이 방금 지났거나 서버가 이미 정리했다 — 새 대화로 간다.
          if (e.code != ApiErrorCode.sessionNotResumable) rethrow;
          _enter(await _startFresh(repo));
          return;
        }
        if (!mounted) return;
        // 이어하기는 새 7분을 주지 않는다 (NFR-06) — 남은 시간을 그대로 쓴다.
        session = _asStart(r);
        resumedChatGroupId = r.resumedChatGroupId;
      } else {
        final started = await repo.startSession();
        if (!mounted) return;
        switch (started) {
          case SessionOpened(:final session):
            // 자리가 있었다 — 줄이 없거나 대기열이 꺼져 있다.
            _enter(session);
            return;
          case SessionQueued(:final ticket):
            _waitInQueue(ticket);
            return;
        }
      }
      // **지금은 `chat_group_id`를 소켓에 싣지 않는다** (2026-09-06).
      //
      // 실사용에서 **이어하기로 들어간 대화가 매번 `closed 1000`으로 끊겼다.**
      // 그 연결에만 다른 것이 이 값 하나였다 — Hume이 이미 끝난 대화 그룹을
      // 이어달라는 요청으로 받고 **연결을 수락한 뒤 정상 종료**한 것으로
      // 보인다. 값을 빼면 이어하기는 그대로 되고 **이전 대화 맥락만**
      // 복원되지 않는다(백엔드도 같은 판단 — `request/app/chat-group-id.md`).
      //
      // F2-07은 P1이고 스코프 컷 3번이다. **대화가 아예 안 되는 것보다
      // 맥락이 안 붙는 편이 낫다.** 원인이 확정되면 되돌린다 —
      // `request/ai/hume-chat-group-resume.md`.
      _enter(session, resumed: true);
      _unusedChatGroup = resumedChatGroupId;
    } on _Queued {
      // 줄을 섰다 — 오류가 아니다. 화면은 이미 대기 상태다.
    } catch (e) {
      if (!mounted) return;
      // 원인별 문구는 F2-04 — 여기서는 "시작할 수 없다"로 모은다.
      setState(() {
        _heard = Env.showErrorDetail
            ? (e is ApiException ? '${e.statusCode} ${e.code} ${e.message}' : '$e')
            : null;
        _state = TalkState.cannotStart;
      });
    }
  }

  /// 이어하기가 성립하지 않을 때 새 대화로 넘어간다.
  ///
  /// 대기열이 켜져 있으면 줄을 서고, 이 함수는 돌아오지 않는다.
  Future<SessionStart> _startFresh(JournalRepository repo) async {
    final started = await repo.startSession();
    switch (started) {
      case SessionOpened(:final session):
        return session;
      case SessionQueued(:final ticket):
        _waitInQueue(ticket);
        // 줄을 섰다 — 세션은 폴링이 가져온다.
        throw const _Queued();
    }
  }

  /// 이어하기로 들어온 세션인지 — `E0700` 처리가 갈린다.
  bool _resumed = false;

  /// 이어하기로 들어왔을 때 남아 있던 시간(초). 새 대화면 null이다.
  int? _remainingSec;

  /// 백엔드가 준 `chat_group_id`. **지금은 소켓에 싣지 않는다**(위 주석).
  /// 값 자체는 계속 받아 두어 원인이 밝혀지면 바로 되돌릴 수 있게 한다.
  // ignore: unused_field
  String? _unusedChatGroup;

  /// Hume 동시 접속 상한을 소켓에서 만났다 (`E0700`, §2-14).
  ///
  /// **이어하기면 새 세션을 시작하지 않는다.** 시작하는 순간 중단된 세션이
  /// 닫혀 이어할 대화가 사라진다 — 잠시 뒤 이어하기를 다시 시도한다.
  /// 새 대화였다면 §2-4부터 다시 태운다(그러면 서버가 줄을 세워 준다).
  void _onBusy() {
    _stopThinking();
    setState(() {
      _state = TalkState.queued;
      _ticket = null;
    });
    _queueTimer?.cancel();
    _queueTimer = Timer(const Duration(seconds: 3), () {
      // `_open()`은 `me().openSession`을 먼저 보므로, 이어하기 중이었다면
      // 다시 이어하기로 들어간다 — 새 세션을 만들지 않는다.
      if (mounted) _open();
    });
  }

  /// 세션을 손에 넣었다 — 시계를 걸고 소켓을 연다.
  void _enter(
    SessionStart session, {
    bool resumed = false,
    String? chatGroupId,
  }) {
    _stopQueue();
    _resumed = resumed;
    // 이어하기면 서버가 남은 시간을 `hardCutSec`으로 준다 (§2-5-1).
    _remainingSec = resumed ? session.hardCutSec : null;
    // 새 대화면 이전 그룹을 지운다 — 남겨두면 다음 소켓에 실린다.
    ref.read(chatGroupIdProvider.notifier).state = chatGroupId;
    ref.read(activeSessionProvider.notifier).state = session;

    // 샘플 모드는 소켓을 열지 않는다 — 단, 검증용 주소가 주어졌으면 그쪽으로
    // 붙는다. 그 주소는 Hume이 아니다 (`Env.eviWsUrl`).
    final connects =
        ref.read(dataModeProvider) != DataMode.sample || Env.hasEviOverride;

    // **새 대화를 「듣고 있습니다」로 시작하지 않는다.** AI가 먼저 인사하므로
    // 그 사이에 사용자가 말을 시작하면 인사가 끊긴다 (2026-09-08 실사용).
    // 인사가 끝나 마이크가 열릴 때 `EviMicLive`가 와서 넘어간다.
    //
    // 소켓을 열지 않는 샘플 모드는 그 사건이 오지 않으므로 그대로 듣는다.
    setState(() => _state = switch (true) {
          _ when resumed => TalkState.resumed,
          _ when connects => TalkState.connecting,
          _ => TalkState.listening,
        });
    _startClock(session.hardCutSec);

    if (!connects) return;
    _connectVoice(session, chatGroupId);
  }

  // ---------------------------------------------------------------------
  // 대기열 (§2-14)
  // ---------------------------------------------------------------------

  QueueTicket? _ticket;
  Timer? _queueTimer;

  String? get _queueSub {
    final t = _ticket;
    if (t == null) {
      // 티켓 없이 기다리는 경우 — 소켓에서 상한을 만나 다시 시도하는 중이다.
      return _resumed
          ? '이어할 대화는 그대로 있습니다 · 잠시 뒤 다시 연결합니다'
          : '자리가 나면 바로 시작됩니다';
    }
    return '${t.position}번째로 기다리고 있습니다 · 자리가 나면 바로 시작됩니다';
  }

  /// 줄을 선다. **간격은 서버가 준 `pollIntervalSec`을 쓴다.**
  void _waitInQueue(QueueTicket ticket) {
    setState(() {
      _ticket = ticket;
      _state = TalkState.queued;
    });
    _scheduleQueuePoll(ticket.pollIntervalSec);
  }

  void _scheduleQueuePoll(int seconds) {
    _queueTimer?.cancel();
    _queueTimer = Timer(Duration(seconds: seconds), _pollQueue);
  }

  /// 순번 폴링.
  ///
  /// **멈추면 티켓이 만료된다** — 브라우저를 닫은 사람이 줄을 영원히 막기
  /// 때문이다. 만료(404)면 조용히 §2-4부터 다시 시작한다.
  Future<void> _pollQueue() async {
    final ticket = _ticket;
    if (ticket == null || !mounted) return;
    try {
      final next =
          await ref.read(journalRepositoryProvider).queueTicket(ticket.ticketId);
      if (!mounted) return;
      final session = next.session;
      if (next.isReady && session != null) {
        _enter(session);
        return;
      }
      setState(() => _ticket = next);
      _scheduleQueuePoll(next.pollIntervalSec);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        // 티켓이 만료됐다. 사용자에게 알릴 것이 없다 — 다시 줄을 선다.
        _stopQueue();
        await _open();
        return;
      }
      // 그 외 실패는 폴링만 한 번 건너뛴다. 줄에서 밀려나지 않는다.
      _scheduleQueuePoll(ticket.pollIntervalSec);
    } on Object {
      if (mounted) _scheduleQueuePoll(ticket.pollIntervalSec);
    }
  }

  /// 기다리기 그만두기 — 줄에서 빠지고 화면을 떠난다.
  Future<void> _leaveQueue() async {
    final ticket = _ticket;
    _stopQueue();
    if (ticket != null) {
      ref
          .read(journalRepositoryProvider)
          .leaveQueue(ticket.ticketId)
          .ignore();
    }
    ref.read(inConversationProvider.notifier).state = false;
    if (mounted) context.pop();
  }

  void _stopQueue() {
    _queueTimer?.cancel();
    _queueTimer = null;
    _ticket = null;
  }

  /// EVI 소켓을 열고 사건을 화면 상태로 옮긴다.
  /// EVI 소켓을 연다.
  ///
  /// **[chatGroupId]는 이어하기일 때만 값이 있다.** 한때 공유 상태
  /// (`chatGroupIdProvider`)를 여기서 직접 읽었는데, 그 값이 **이전 대화의
  /// 것으로 남아 있어 새 대화의 소켓에 실렸다** — Hume은 이미 끝난 대화
  /// 그룹을 이어달라는 요청으로 받고 **연결을 받아들인 뒤 정상 종료(1000)**
  /// 했다. 2026-09-06 실사용에서 "첫 대화 이후 계속 연결이 끊어진다"로
  /// 드러났다. 넘겨받은 값만 쓴다.
  Future<void> _connectVoice(SessionStart session, String? chatGroupId) async {
    final evi = ref.read(eviServiceProvider);
    _eviSub?.cancel();
    _eviSub = evi.events.listen(_onEvi);
    await evi.start(
      accessToken: session.humeAccessToken,
      configId: session.humeConfigId,
      sessionId: session.sessionId,
      resumedChatGroupId: chatGroupId,
      // 새 대화는 AI가 먼저 인사한다. 이어하기는 인사가 없으므로 보류하지
      // 않는다 — 보류하면 12초를 기다린 뒤에야 말이 들어간다.
      holdMicForGreeting: !_resumed,
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
        // F2-07의 원천 — 받자마자 서버에 올린다 (§2-5-2).
        if (chatGroupId != null) {
          ref.read(chatGroupIdProvider.notifier).state = chatGroupId;
          _saveChatGroup(chatGroupId);
        }
        // **연결됐다고 「듣고 있습니다」로 가지 않는다.** AI가 먼저 인사하므로
        // 그 사이에 사용자가 말을 시작하면 인사가 끊긴다 — `EviMicLive`가
        // 올 때 넘어간다 (2026-09-08 실사용).
        if (!ref.read(eviServiceProvider).micHeld) {
          setState(() => _state = TalkState.listening);
        }

      case EviMicLive():
        setState(() => _state = TalkState.listening);

      case EviUserSpoke(:final text):
        // 잠깐만 보여준다 — 다음 발화가 오거나 3초가 지나면 사라진다.
        _showHeard(text);

      case EviAssistantSpoke():
        _stopThinking();
        setState(() => _state = TalkState.speaking);

      case EviAssistantDone():
        _stopThinking();
        // 인사 보류 중이면 아직 마이크가 닫혀 있다 — 「듣고 있습니다」로
        // 먼저 넘어가면 사용자가 말해도 안 들어간다.
        if (!ref.read(eviServiceProvider).micHeld) {
          setState(() => _state = TalkState.listening);
        }

      case EviUserInterruption():
        _stopThinking();
        setState(() => _state = TalkState.listening);

      case EviClosed(:final code, :final reason):
        // 대화 중 끊긴 것이면 알린다. 우리가 끊은 경우는 이미 화면을 떠났다.
        setState(() {
          if (Env.showErrorDetail) {
            _heard = 'closed ${code ?? '-'} ${reason ?? ''}'.trim();
          }
          _state = TalkState.networkLost;
        });

      case EviFailed(:final reason):
        if (reason == EviFailure.busy) {
          _onBusy();
          return;
        }
        _stopThinking();
        if (Env.showErrorDetail) {
          _heard = '$reason ${ref.read(eviServiceProvider).lastSocketError ?? ''}'
              .trim();
        }
        setState(() => _state = switch (reason) {
              EviFailure.micDenied => TalkState.micDenied,
              EviFailure.network => TalkState.networkLost,
              EviFailure.auth => TalkState.cannotStart,
              EviFailure.busy || EviFailure.unknown => TalkState.cannotStart,
            });
    }
  }

  /// 「말 다 했어요」 — 소리 전송을 끊고 **곧바로** 「생각 중」으로 간다.
  ///
  /// Hume이 턴을 확정하는 데는 여전히 1.8초가 걸리지만(`end_of_turn_silence_ms`),
  /// 그 1.8초를 **기다리는 화면**과 「듣고 있습니다」로 남아 있는 화면은 다르다.
  void _finishTurn() {
    ref.read(eviServiceProvider).finishTurn();
    _heardTimer?.cancel();
    _slowTimer?.cancel();
    setState(() {
      _slowThinking = false;
      _state = TalkState.thinking;
    });
    _breath.repeat(reverse: true);
    // 여기서부터 재는 것이 사용자가 실제로 기다리는 시간이다.
    _slowTimer = Timer(_slowAfter + const Duration(milliseconds: 1800), () {
      if (mounted && _state == TalkState.thinking) {
        setState(() => _slowThinking = true);
      }
    });
  }

  /// 방금 들은 말을 잠깐 띄우고 **「생각 중」으로 넘어간다** (§6-1 절충안).
  ///
  /// EVI가 `user_message`를 주는 시점이 전사가 확정된 순간이고, 그 뒤로
  /// 분석·응답 호출이 순차로 돈다 — 여기서부터가 사용자가 기다리는 구간이다.
  void _showHeard(String text) {
    _heardTimer?.cancel();
    _slowTimer?.cancel();
    setState(() {
      _heard = text;
      _slowThinking = false;
      _state = TalkState.thinking;
    });
    _breath.repeat(reverse: true);
    _heardTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _heard = null);
    });
    _slowTimer = Timer(_slowAfter, () {
      if (mounted && _state == TalkState.thinking) {
        setState(() => _slowThinking = true);
      }
    });
  }

  /// `chat_group_id`를 서버에 올린다 (§2-5-2, v1.8).
  ///
  /// **실패해도 재시도하지 않고 사용자에게도 알리지 않는다.** 이 값이 없으면
  /// 그 세션만 이어하기의 맥락 복원이 빠질 뿐 대화는 멀쩡하고, 대화 중에
  /// 재시도 루프를 돌릴 이유가 없다. 서버가 멱등이라 재연결 때 다시 보낸다.
  void _saveChatGroup(String chatGroupId) {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;
    ref
        .read(journalRepositoryProvider)
        .putChatGroup(session.sessionId, chatGroupId)
        .ignore();
  }

  /// 기다림이 끝났다 — 응답이 오기 시작했거나 상태가 바뀌었다.
  void _stopThinking() {
    _slowTimer?.cancel();
    _slowThinking = false;
    if (_breath.isAnimating) _breath.stop();
    _breath.value = 0;
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
        TalkState.thinking ||
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
    _queueTimer?.cancel();
    _breath.dispose();
    _heardTimer?.cancel();
    _slowTimer?.cancel();
    _nearEndTimer?.cancel();
    _hardCutTimer?.cancel();
    _eviSub?.cancel();
    super.dispose();
  }

  /// 화면이 트리에서 빠질 때 — **여기서 정리한다.**
  ///
  /// `dispose()`에서는 `ref`를 쓸 수 없다("Cannot use ref after the widget was
  /// disposed"). 처음에 거기 넣었다가 위젯 테스트가 잡았다.
  @override
  void deactivate() {
    // **화면을 어떻게 벗어나든 마이크를 끈다.**
    //
    // 「대화 마치기」는 `_end()`가 정리하지만 **뒤로 가기는 그 경로를 타지
    // 않는다.** 2026-09-06 통합에서 실제로 걸렸다 — 홈으로 돌아온 뒤에도
    // 마이크가 열려 있어 소리가 계속 Hume으로 나갔다. 화면에는 아무 표시가
    // 없으므로 **사용자는 자기 말이 나가는 줄 모른다.** 요금보다 이쪽이 더
    // 무겁다.
    //
    // `dispose`는 기다릴 수 없어 던져만 둔다. `stop()`은 예외를 밖으로
    // 내보내지 않는다.
    ref.read(eviServiceProvider).stop();

    // 세션을 놓는다. 폴링(§2-13)은 `liveSignalProvider`가 `autoDispose`라
    // 듣는 사람이 없어지는 순간 알아서 멈춘다. 세션 자체는 서버가
    // 타임아웃으로 정리한다 (§2-6 `endReason: timeout`).
    //
    // **상태 쓰기는 한 박자 미룬다** — 생명주기 콜백 안에서 프로바이더를
    // 고치면 "위젯 트리를 만드는 중"이라 막힌다. 알림 객체는 위젯이 아니라
    // 컨테이너의 것이라 나중에 써도 안전하다.
    final session = ref.read(activeSessionProvider.notifier);
    final inConversation = ref.read(inConversationProvider.notifier);

    // **홈이 `openSession`을 다시 읽게 한다.** 「대화 마치기」는 이미
    // 무효화하지만 **뒤로 가기는 그 경로를 타지 않아서**, 대화 도중에 나오면
    // 홈이 새로고침 전까지 "오늘 이야기하기"를 그대로 보여줬다 — 실제로는
    // 이어할 대화가 열려 있는데도(F2-07). 2026-09-06 실사용에서 나왔다.
    final container = ProviderScope.containerOf(context, listen: false);
    Future.microtask(() {
      session.state = null;
      inConversation.state = false;
      container.invalidate(meProvider);
    });
    super.deactivate();
  }

  /// S07은 `crisisDetected`의 **false → true 전이에서 한 번만** 띄운다
  /// (계약 §2-13). 폴링이 계속 true를 줘도 다시 띄우지 않는다.
  bool _crisisShown = false;

  _Ring get _ring => switch (_state) {
        TalkState.connecting =>
          const _Ring('연결하고 있습니다', size: 176, offset: 4, cool: 0.30, warm: 0.20),
        // **남은 시간은 서버가 준 값이다.** 여기 "4분 42초"가 상수로 박혀
        // 있었다 (2026-09-07) — 실제로 얼마가 남았든 같은 숫자를 말했다.
        TalkState.resumed => _Ring(
            '이어서 듣고 있습니다',
            size: 200,
            offset: 8,
            cool: 0.85,
            warm: 0.60,
            sub: _remainingSec == null
                ? '중단된 대화를 이어갑니다'
                : '중단된 대화를 이어갑니다'
                    ' · 남은 시간 ${SessionClock.spell(_remainingSec!)}',
          ),
        TalkState.listening => const _Ring(
            '듣고 있습니다',
            size: 200,
            offset: 8,
            cool: 0.85,
            warm: 0.60,
            canFinishTurn: true,
          ),
        TalkState.speaking =>
          const _Ring('말하고 있습니다', size: 168, offset: 3, cool: 0.50, warm: 0.35),
        TalkState.quiet => const _Ring('듣고 있습니다',
            size: 184, offset: 5, cool: 0.50, warm: 0.32, canFinishTurn: true),
        // 듣는 중보다 링이 **조금 작고 가깝다** — 밖으로 열려 있던 것이
        // 안으로 모이는 모양이다. 색은 그대로다 (FR-030).
        TalkState.thinking => _Ring(
            '생각하고 있습니다',
            size: 188,
            offset: 4,
            cool: 0.62,
            warm: 0.44,
            sub: _slowThinking ? '조금 오래 걸리고 있습니다' : null,
          ),
        TalkState.nearEnd => const _Ring(
            '듣고 있습니다',
            size: 196,
            offset: 7,
            cool: 0.80,
            warm: 0.55,
            nearEnd: true,
            canFinishTurn: true,
          ),
        // 아직 대화가 아니라 **기다림**이다 — 링을 작고 흐리게 둔다.
        TalkState.queued => _Ring(
            '기다리고 있습니다',
            size: 164,
            offset: 3,
            cool: 0.22,
            warm: 0.16,
            sub: _queueSub,
            cta: '기다리기 그만두기',
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
    // **`ref.listen`은 build 안에서만 쓸 수 있다.** 한때 `_body()`에서 불렀는데
    // 그건 `LayoutBuilder`의 빌더 안이라 규약 위반이다 — 릴리스에서는
    // assert가 꺼져 조용히 돌지만 구독이 새는 자리다 (2026-09-06 위젯
    // 테스트가 잡았다).
    //
    // 위기 신호는 전이에서 한 번만 (§2-13).
    ref.listen(liveSignalProvider, (_, next) {
      final v = next.valueOrNull;
      if (v != null) onCrisisSignal(v.crisisDetected);
    });

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
              if (_state == TalkState.thinking)
                AnimatedBuilder(
                  animation: _breath,
                  builder: (context, _) {
                    // 폭이 좁다 — 숨이지 깜빡임이 아니다.
                    final t = Curves.easeInOut.transform(_breath.value);
                    return RingPair(
                      size: r.size + t * 6,
                      offset: r.offset + t * 3,
                      coolOpacity: r.cool - t * 0.14,
                      warmOpacity: r.warm - t * 0.10,
                    );
                  },
                )
              else
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
                    // 진단 줄. **클래스만 만들어 놓고 붙이는 것을 잊어
                    // 「숫자를 보라」고 말하면서 화면에는 없던 일이 있었다**
                    // (2026-09-06). 만든 계측은 반드시 보이는 곳에 둔다.
                    if (Env.showErrorDetail)
                      _DiagnosticLine(evi: ref.read(eviServiceProvider)),
                    // 실제 발화가 들어오면 대본 문구 대신 그것을 띄운다.
                    // **AI 발화는 여기 오지 않는다** — 소리로만 듣는다 (§6-1).
                    if (_heard != null) ...[
                      const SizedBox(height: Space.lg + 2),
                      Text(
                        _heard!,
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

        // **사용자가 자기 턴을 끝낸다** (2026-09-08 요청).
        //
        // Hume은 침묵 1.8초를 봐야 턴을 확정한다. 그 사이 숨소리·주변 소음이
        // 들어가면 계속 열려 있어 **한참을 기다리게 된다.** 눌러서 끊는다.
        if (r.canFinishTurn) ...[
          FilledAction(label: '말 다 했어요', height: 56, onPressed: _finishTurn),
          const SizedBox(height: Space.xs),
          // 대화를 끝내는 길은 늘 열어 둔다 — 다만 지금 할 일은 위쪽이라
          // 조용한 글자로 둔다.
          GestureDetector(
            onTap: _end,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: Space.tapMin,
              child: Center(
                child: Text(
                  '대화 마치기',
                  style: AppType.sans(
                    size: AppType.captionSizeLg,
                    color: t.muted,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ] else if (r.cta == null)
          OutlineAction(label: '대화 마치기', height: 56, onPressed: _end)
        else if (_state == TalkState.queued)
          // 줄에서 빠지는 것은 파괴적 동작이 아니다 — 테두리 버튼으로 둔다.
          OutlineAction(label: r.cta!, height: 56, onPressed: _leaveQueue)
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
    this.sub,
    this.error,
    this.cta,
    this.nearEnd = false,
    this.canFinishTurn = false,
  });

  final String label;
  final double size;
  final double offset;
  final double cool;
  final double warm;
  final String? sub;
  final String? error;
  final String? cta;
  final bool nearEnd;

  /// 「말 다 했어요」를 보여줄 상태인지 — 마이크가 살아 있고 AI가 말하고 있지
  /// 않을 때만이다.
  final bool canFinishTurn;
}

/// 진단 한 줄 — **`SHOW_ERROR_DETAIL`에서만 나온다.**
///
/// 끊김의 책임을 가르기 위한 것이다. `끼어들기`가 늘면 Hume이 사용자가
/// 말한다고 판단한 것이고(에코·VAD), `조각`만 늘고 소리가 멈추면 우리 재생이다.
class _DiagnosticLine extends StatefulWidget {
  const _DiagnosticLine({required this.evi});

  final EviService evi;

  @override
  State<_DiagnosticLine> createState() => _DiagnosticLineState();
}

class _DiagnosticLineState extends State<_DiagnosticLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final speaker = widget.evi.speaker;
    final chunks = speaker is AudioPlayersSpeaker ? speaker.received : -1;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Text(
        '마이크 ${widget.evi.micLevel} (최대 ${widget.evi.micPeak}) · '
        'AI 발화 ${widget.evi.assistantTurns} · 조각 $chunks · '
        '끼어들기 ${widget.evi.interruptions}',
        textAlign: TextAlign.center,
        style: AppType.sans(
          size: AppType.labelSize,
          color: t.faint,
          height: 1.2,
        ),
      ),
    );
  }
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
    TalkState.thinking: '생각 중',
    TalkState.speaking: '말하는 중',
    TalkState.quiet: '조용',
    TalkState.nearEnd: '마무리 임박',
    TalkState.micDenied: '마이크 거부',
    TalkState.networkLost: '네트워크 끊김',
    TalkState.cannotStart: '연결 불가',
    TalkState.queued: '대기열',
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
