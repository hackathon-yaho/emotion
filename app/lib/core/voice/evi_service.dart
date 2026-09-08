import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';

import 'evi_event.dart';
import 'mic.dart';
import 'speaker.dart';

/// Hume EVI 소켓 (spec F2-02 · 계약 §4).
///
/// ```
/// wss://api.hume.ai/v0/evi/chat
///   ?access_token={humeAccessToken}&config_id={humeConfigId}
///   &custom_session_id={sessionId}
/// ```
///
/// 지키는 것들 —
///
/// - **Hume API 키를 앱에 두지 않는다** (FR-013). 여기 들어오는 것은
///   `session/start`가 발급한 단기 토큰뿐이다
/// - **`language_model_api_key`를 `session_settings`에 넣지 않는다** — 웹
///   번들에 노출된다. CLM 인증은 AI서버가 `custom_session_id`를 백엔드로
///   검증하는 방식이다 (계약 §4, v1.3)
/// - **프로소디를 파싱하지 않는다.** `user_message`에 48종 점수가 실려 오지만
///   앱은 텍스트만 꺼낸다 (FR-030·031)
/// - **음성을 파일로 쓰지 않는다** (FR-041). 마이크 바이트는 소켓으로만 나가고
///   재생 조각은 메모리에서 버린다
/// - **어떤 실패에서도 예외를 밖으로 던지지 않는다** (F2-04 수용 기준).
///   전부 [EviFailed]로 내려간다
class EviService {
  EviService({
    required this.mic,
    required this.speaker,
    this.connect = WebSocketChannel.connect,
    Uri Function(Map<String, String> query)? endpoint,
    // 테스트가 로컬 소켓을 물릴 수 있게 주소 조립도 갈아끼운다.
  }) : _endpoint = endpoint ?? _defaultEndpoint;

  final Mic mic;
  final Speaker speaker;
  final WebSocketChannel Function(Uri) connect;
  final Uri Function(Map<String, String>) _endpoint;

  static Uri _defaultEndpoint(Map<String, String> query) {
    // 개발·검증용 주소가 있으면 그쪽으로 (Env.eviWsUrl). 배포 빌드에는 값이
    // 없어 항상 Hume이다.
    final override = Env.eviWsUrl;
    if (override != null) {
      return Uri.parse(override).replace(queryParameters: query);
    }
    return Uri(
      scheme: 'wss',
      host: 'api.hume.ai',
      path: '/v0/evi/chat',
      queryParameters: query,
    );
  }

  final _events = StreamController<EviEvent>.broadcast();
  Stream<EviEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _closing = false;

  /// 연결 세대. `start()`마다 오르고 `stop()`에서도 오른다 — 옛 연결의 콜백은
  /// 이 값이 달라진 것으로 자기가 낡았음을 안다.
  int _generation = 0;

  /// 진단용 계수기 — `SHOW_ERROR_DETAIL`에서만 화면에 쓴다.
  ///
  /// **끊김의 책임이 어디인지 가른다** — 끼어들기가 늘면 Hume이 사용자가
  /// 말한다고 판단한 것이고(에코·VAD), 조각만 늘고 재생이 멈추면 우리 쪽이다.
  int interruptions = 0;
  int assistantTurns = 0;

  /// 지금 보내고 있는 소리의 크기 (0~100).
  ///
  /// **우리가 소리를 담고 있는지**를 가른다. 말하는데도 0에 가까우면 캡처가
  /// 잘못된 것이고, 값이 멀쩡한데 Hume이 "못 들었다"고 하면 그 뒤쪽이다.
  int micLevel = 0;
  int micPeak = 0;

  /// **첫 인사가 끝날 때까지 마이크 소리를 보내지 않는다.**
  ///
  /// EVI Config에 첫 인사말이 있어 연결 직후 AI가 먼저 말한다. 그런데 화면이
  /// 곧바로 「듣고 있습니다」가 되면 사용자는 그때 말을 시작하고, Hume은 그것을
  /// 끼어들기로 읽어 **인사를 자기 말 도중에 끊는다** — 2026-09-08 실사용에서
  /// 나왔다. 스피커 소리가 마이크로 되돌아가도 같은 일이 벌어진다.
  ///
  /// 보류는 **첫 턴 한 번뿐이다.** 그 뒤의 끼어들기는 기능이라 막지 않는다.
  bool _micHeld = false;
  bool get micHeld => _micHeld;

  Timer? _holdTimer;

  /// 마지막 소켓 오류 문구 — 진단용(`SHOW_ERROR_DETAIL`).
  String? _lastSocketError;
  String? get lastSocketError => _lastSocketError;

  /// 연결. **소켓을 먼저 열고 마이크를 나중에 켠다** — 순서를 뒤집으면 인증
  /// 실패인데도 마이크 권한 창이 먼저 떠서 사용자가 원인을 오해한다.
  Future<void> start({
    required String accessToken,
    required String configId,
    required String sessionId,
    String? resumedChatGroupId,
    bool holdMicForGreeting = false,
  }) async {
    // **이전 연결을 먼저 끝낸다.** 안 그러면 옛 소켓이 살아남아, 그 소켓이
    // 나중에 닫힐 때 `onDone`이 **새 대화 화면을** "연결이 끊어졌습니다"로
    // 만든다. 2026-09-06 실사용에서 "첫 대화 이후 계속 끊긴다"의 실제
    // 원인이었다 — 사용자는 "이전 대화가 남아 있는 것 같다"고 했고 정확했다.
    await stop();

    // 이 연결의 세대. 콜백은 자기 세대가 현재일 때만 일한다 — 늦게 도착한
    // 옛 연결의 이벤트가 새 대화를 건드리지 못하게 하는 유일한 방법이다.
    final gen = ++_generation;
    _closing = false;
    // **새 대화는 0에서 시작한다.** 이 서비스는 앱 수명 내내 사는 한 개짜리라
    // (`eviServiceProvider`) 계수기를 안 지우면 두 번째 대화의 화면에 첫
    // 대화의 턴 수가 얹혀 보인다 — 진단이 거짓말을 하게 된다.
    interruptions = 0;
    assistantTurns = 0;
    micLevel = 0;
    micPeak = 0;
    _lastSocketError = null;
    _holdTimer?.cancel();
    _micHeld = holdMicForGreeting;
    if (_micHeld) {
      // **인사가 오지 않는 Config도 있을 수 있다.** 그때 보류가 안 풀리면
      // 대화가 통째로 죽으므로, 기다림에는 반드시 끝이 있어야 한다.
      _holdTimer = Timer(const Duration(seconds: 12), () => _releaseMic(gen));
    }
    try {
      final channel = connect(_endpoint({
        'access_token': accessToken,
        'config_id': configId,
        // 계약 §4 — AI서버가 이 값으로 세션을 검증한다.
        'custom_session_id': sessionId,
        'resumed_chat_group_id': ?resumedChatGroupId,
      }));
      _channel = channel;
      _socketSub = channel.stream.listen(
        (frame) {
          if (gen != _generation) return;
          _onFrame(frame);
        },
        onError: (Object e) {
          if (gen != _generation) return;
          _lastSocketError = e.toString();
          _fail(EviFailure.network);
        },
        onDone: () {
          if (gen != _generation || _closing) return;
          // 닫힘 코드·사유를 함께 올린다 — 거절인지 진짜 끊김인지는 이걸로만
          // 갈린다.
          _emit(EviClosed(
            code: channel.closeCode,
            reason: channel.closeReason,
          ));
        },
      );

      // 오디오 형식을 먼저 알린다. 이걸 보내기 전에 오디오를 밀면 Hume이
      // 기본값으로 해석해 알아듣지 못한다.
      _send({
        'type': 'session_settings',
        // **`custom_session_id`는 여기로 보내야 한다.** 소켓 URL 쿼리로만
        // 보내면 Hume이 그 경로로는 받지 않아 **CLM 호출에 세션 id가 실리지
        // 않고**, AI서버가 fail-closed로 401을 돌려준다(계약 §4). 그러면
        // Hume은 응답을 못 받아 채팅을 끝내는데, 앱에는 **`closed 1000`
        // (정상 종료)** 으로 보여 원인이 드러나지 않는다 — 2026-09-06에
        // 이것으로 한참 헤맸고 AI가 CLM 쪽 401 로그로 짚어 줬다.
        //
        // 쿼리에도 계속 싣는다. 둘 다 보내는 것이 해롭지 않고, Hume이 어느
        // 쪽을 읽는지에 우리 대화가 걸리지 않게 한다.
        'custom_session_id': sessionId,
        'audio': {
          'encoding': 'linear16',
          'sample_rate': Mic.sampleRate,
          'channels': Mic.channels,
        },
      });
    } on Object {
      _fail(EviFailure.auth);
      return;
    }

    try {
      final bytes = await mic.open();
      if (gen != _generation) return; // 그사이 새 대화가 시작됐다
      _micSub = bytes.listen(
        (pcm) {
          if (gen != _generation) return;
          _sendAudio(pcm);
        },
        onError: (_) {
          if (gen == _generation) _fail(EviFailure.micDenied);
        },
      );
    } on MicDenied {
      if (gen == _generation) _fail(EviFailure.micDenied);
    } on Object {
      if (gen == _generation) _fail(EviFailure.micDenied);
    }
  }

  /// 종료. **끊는 것 자체가 실패해도 조용히 끝낸다** — 대화는 이미 끝났다.
  Future<void> stop() async {
    _closing = true;
    _generation++;
    _holdTimer?.cancel();
    _holdTimer = null;
    _micHeld = false;
    await _micSub?.cancel();
    _micSub = null;
    await mic.close().catchError((_) {});
    await speaker.stop().catchError((_) {});
    await _socketSub?.cancel();
    _socketSub = null;
    await _channel?.sink.close().catchError((_) {});
    _channel = null;
  }

  Future<void> dispose() async {
    await stop();
    await speaker.dispose().catchError((_) {});
    await _events.close();
  }

  // -------------------------------------------------------------------------

  void _sendAudio(Uint8List pcm) {
    // **계측은 보류 중에도 한다** — 마이크가 살아 있는지는 보류와 별개다.
    _measure(pcm);
    if (_micHeld) return;
    _send({'type': 'audio_input', 'data': base64Encode(pcm)});
  }

  /// PCM16의 실효값을 0~100으로 옮긴다. 진단용이므로 정확도보다 싸게.
  void _measure(Uint8List pcm) {
    // **진단이 대화를 죽이지 못하게 한다.** 홀수 길이 조각이면 sublistView가
    // 던진다 — 계측을 못 하는 것과 대화가 끊기는 것은 값이 다르다.
    if (pcm.length < 2) return;
    // sublistView의 범위는 **원본 바이트 색인**이다 — 표본 수가 아니다.
    final samples = Int16List.sublistView(pcm, 0, pcm.length - pcm.length % 2);
    if (samples.isEmpty) return;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples.length);
    final level = (rms / 32768 * 300).clamp(0, 100).round();
    // 값이 튀지 않게 지수 평활 — 눈으로 읽을 수 있어야 한다.
    micLevel = ((micLevel * 3 + level) / 4).round();
    if (level > micPeak) micPeak = level;
  }

  /// 재생이 다 끝나면 마이크를 연다. 200ms마다 보고, 오래 끌지 않는다.
  void _releaseWhenQuiet(int gen) {
    _holdTimer?.cancel();
    var waited = Duration.zero;
    const step = Duration(milliseconds: 200);
    _holdTimer = Timer.periodic(step, (timer) {
      if (gen != _generation) {
        timer.cancel();
        return;
      }
      waited += step;
      if (speaker.idle || waited > const Duration(seconds: 12)) {
        timer.cancel();
        _releaseMic(gen);
      }
    });
  }

  void _releaseMic(int gen) {
    if (gen != _generation || !_micHeld) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _micHeld = false;
    _emit(const EviMicLive());
  }

  void _send(Map<String, Object?> message) {
    final sink = _channel?.sink;
    if (sink == null) return;
    try {
      sink.add(jsonEncode(message));
    } on Object {
      _fail(EviFailure.network);
    }
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) return;
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } on Object {
      // 알 수 없는 프레임 하나로 대화를 끊지 않는다.
      return;
    }

    switch (json['type']) {
      case 'chat_metadata':
        _emit(EviConnected(
          chatGroupId: json['chat_group_id'] as String?,
          chatId: json['chat_id'] as String?,
        ));

      case 'user_message':
        // **`models.prosody`를 읽지 않는다.** 텍스트만 꺼낸다.
        final text = _content(json);
        if (text != null) _emit(EviUserSpoke(text));

      case 'assistant_message':
        assistantTurns++;
        final text = _content(json);
        if (text != null) _emit(EviAssistantSpoke(text));

      case 'audio_output':
        final data = json['data'] as String?;
        if (data == null) break;
        try {
          speaker.enqueue(base64Decode(data));
        } on Object {
          // 조각 하나가 깨져도 대화를 끊지 않는다.
        }

      case 'assistant_end':
        _emit(const EviAssistantDone());
        // `assistant_end`는 **조각을 다 보냈다**는 뜻이다. 아직 스피커에서
        // 나오는 중이라, 여기서 마이크를 열면 남은 인사가 마이크로 되돌아가
        // 자기 말을 끊는다. 재생이 비는 것을 보고 연다.
        if (_micHeld) _releaseWhenQuiet(_generation);

      case 'user_interruption':
        interruptions++;
        // 큐를 비우지 않으면 사용자가 끊었는데도 AI가 계속 말한다.
        speaker.stop().catchError((_) {});
        _emit(const EviUserInterruption());

      case 'error':
        // Hume의 오류 문구를 사용자에게 그대로 보여주지 않는다. 인증 계열만
        // 갈라내고 나머지는 unknown이다 — 분류하지 못한 것을 auth로 뭉개면
        // "다시 시도"가 소용없는 상황에서도 다시 시도를 권하게 된다.
        final slug = (json['slug'] ?? json['code'] ?? '').toString();
        final message = (json['message'] ?? '').toString().toLowerCase();
        // E0700 — 동시 접속 상한. 코드가 바뀔 수 있어 문구도 함께 본다.
        final busy = slug.contains('E0700') ||
            message.contains('too many active chats');
        _fail(switch (true) {
          _ when busy => EviFailure.busy,
          _ when slug.contains('auth') || slug.contains('token') =>
            EviFailure.auth,
          _ => EviFailure.unknown,
        });
    }
  }

  /// `{"message": {"content": "..."}}`에서 텍스트만.
  String? _content(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is! Map<String, dynamic>) return null;
    final content = message['content'];
    return content is String && content.isNotEmpty ? content : null;
  }

  void _fail(EviFailure reason) => _emit(EviFailed(reason));

  void _emit(EviEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
