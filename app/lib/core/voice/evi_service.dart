import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  /// **마이크 소리는 실시간으로 흘리지 않는다 — 모아 두다가 버튼에 보낸다.**
  ///
  /// 2026-09-18 결정(design-system 결정 32). 그 전까지는 소리를 계속 Hume에
  /// 흘리고 Hume의 침묵 판정(1.8초)에 턴 끝을 맡겼다. 그 틈에서 버그가
  /// 줄줄이 나왔다 — 숨소리가 턴이 되고, 스피커 에코가 발화로 읽히고, 말
  /// 중간의 침묵에 턴이 쪼개지고, 전사가 느린 날엔 화면이 거짓말을 했다.
  /// **버튼을 누를 때만 보내면 그 틈이 없다.** 대가는 손을 안 쓰는 대화가
  /// 아니게 되는 것과, 턴마다 뭉친 소리를 Hume이 처리하는 1~2초다.
  final _turnFrames = <Uint8List>[];
  int _turnBytes = 0;
  bool _turnHasSpeech = false;

  /// 한 턴에 모아 두는 상한 — 약 4분. 넘으면 오래된 것부터 버린다.
  static const _turnCap = 32000 * 240;

  /// **첫 인사가 끝날 때까지는 소리를 버린다** (결정 27).
  ///
  /// 연결 직후 AI가 먼저 인사한다. 그동안 들어온 소리를 모아 두면 인사가 끝난
  /// 뒤 첫 버튼에 실려 나가는데, 그건 대개 인사를 들으며 낸 소리다.
  bool _discarding = false;

  /// 화면이 「듣고 있습니다」로 넘어갈 시점을 가른다 — 인사가 끝났는지.
  bool get micHeld => _discarding;

  Timer? _holdTimer;

  /// 마지막 `audio_output`을 받은 시각. 조각이 계속 오는 중인지 가른다.
  DateTime? _lastChunkAt;

  /// 직전 조각의 소리 크기(평활 전).
  int _lastLevel = 0;
  int _loudRun = 0;

  /// 이 턴에서 본 **가장 조용한 값** — 그 방의 바닥 소음이다.
  int _floor = 100;

  /// 이어지는 조용한 조각의 바이트 수. 긴 침묵을 잘라내는 데 쓴다.
  int _quietBytes = 0;

  /// 침묵은 이만큼(약 0.8초)만 남기고 잘라낸다.
  ///
  /// Hume은 소리 속 침묵 1.8초를 턴 끝으로 읽는다. 말을 고르느라 쉰 시간을
  /// 그대로 보내면 **한 마디가 두 턴으로 쪼개진다** — 그 판정을 우리 버튼으로
  /// 옮긴 이유 자체가 그것이다.
  static const _quietKeep = 25600;

  /// 뭉쳐 보낸 뒤 붙이는 침묵 — Hume이 턴 끝으로 읽는 데 1.8초가 필요하다.
  /// 여유를 둔다.
  static const _silenceTail = Duration(milliseconds: 2200);

  /// 인사가 **시작될** 때까지 기다리는 시간. 이 안에 아무 말도 없으면 마이크를
  /// 연다 — 오지 않는 인사를 기다리며 사용자 말을 버리지 않는다.
  static const _greetingGrace = Duration(milliseconds: 3500);

  /// 재생이 **끝났다고 인정하기까지** 조용해야 하는 시간.
  ///
  /// `assistant_end`는 "조각을 다 보냈다"가 아니라 **메시지가 끝났다**는 뜻이라
  /// 그 뒤로도 `audio_output`이 온다. 큐가 잠깐 빈 순간을 재생 끝으로 읽으면
  /// **인사 도중에 마이크가 열려** 사용자가 말하는 순간 인사가 끊긴다 —
  /// 2026-09-14 테스트에서 "될 때도 있고 안 될 때도 있다"로 나온 것이 이것이다.
  static const _quietFor = Duration(milliseconds: 700);

  /// 인사가 시작된 뒤 끝나기를 기다리는 상한.
  static const _holdCap = Duration(seconds: 15);

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
    _clearTurn();
    _discarding = holdMicForGreeting;
    if (_discarding) {
      // **인사가 시작될 때까지만 짧게 기다린다.**
      //
      // 종전에는 12초를 기다렸다. 인사가 오지 않는 경우(Config·계정 문제,
      // 이어하기한 채팅)에 **사용자가 12초 동안 말해도 한 마디도 전달되지
      // 않았다** — "AI가 한 번도 말을 안 했다"의 모양이 이것이다. 인사가
      // 실제로 시작되면(`assistant_message`) 그때부터 끝까지 기다린다.
      _holdTimer = Timer(_greetingGrace, () => _releaseMic(gen));
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
    _discarding = false;
    _clearTurn();
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
    // **계측은 언제나 한다** — 마이크가 살아 있는지는 보내는지와 별개다.
    _measure(pcm);

    // **마이크 대신 같은 길이의 무음을 실시간으로 보낸다.**
    //
    // Hume의 턴 판정은 소리가 계속 흘러 들어와야 돌아간다. 버튼 뒤에 아무것도
    // 안 보내자 뭉쳐 보낸 말에서 턴이 확정되지 않았다 — 「말이 전달되지
    // 않았습니다」가 계속 떴다 (2026-09-18 실사용). 무음을 마이크 박자에 맞춰
    // 보내면 Hume에게는 조용한 방의 라이브 마이크와 같고, 버튼에 뭉친 소리가
    // 들어온 뒤 무음이 이어지니 턴 끝을 읽는다. 마이크 조각을 그대로 박자로
    // 쓰므로 따로 시계가 없다.
    _send({'type': 'audio_input', 'data': base64Encode(Uint8List(pcm.length))});

    if (_discarding) return;

    // 바닥 소음을 갱신하고 말소리를 판정한다.
    if (_lastLevel < _floor) _floor = _lastLevel;
    _loudRun = _lastLevel >= _speechLevel ? _loudRun + 1 : 0;
    if (_loudRun >= 3) _turnHasSpeech = true;

    // **긴 침묵은 잘라낸다.** 바닥 근처면 조용한 조각이다.
    final quiet = _lastLevel <= _floor + 1;
    if (quiet) {
      _quietBytes += pcm.length;
      if (_quietBytes > _quietKeep) return; // 남길 만큼 남겼다
    } else {
      _quietBytes = 0;
    }

    _turnFrames.add(pcm);
    _turnBytes += pcm.length;
    while (_turnBytes > _turnCap && _turnFrames.isNotEmpty) {
      _turnBytes -= _turnFrames.removeAt(0).length;
    }
  }

  /// 지금까지 모인 소리 길이 — 진단용.
  double get bufferedSeconds => _turnBytes / (Mic.sampleRate * 2);

  /// 이 턴에 말소리가 담겼는지 — 아무 말도 없이 버튼을 누른 경우를 가른다.
  bool get turnHasSpeech => _turnHasSpeech;

  /// **버튼** — 모아 둔 소리를 한 번에 보내고 침묵을 덧붙인다.
  ///
  /// 돌아오는 값이 `false`면 **말소리가 없어 보내지 않았다**는 뜻이다. 화면은
  /// 그때 Hume에 물어볼 필요 없이 바로 「들은 말이 없습니다」를 띄운다 —
  /// 종전에는 시간으로 짐작하다가 전사가 느린 날 틀렸다 (2026-09-17).
  bool sendTurn() {
    if (_channel == null) return false;
    if (!_turnHasSpeech) {
      _clearTurn();
      return false;
    }
    for (final frame in _turnFrames) {
      _send({'type': 'audio_input', 'data': base64Encode(frame)});
    }
    // Hume이 턴 끝을 읽으려면 소리 뒤에 침묵이 있어야 한다.
    final tailBytes = Mic.sampleRate * 2 * _silenceTail.inMilliseconds ~/ 1000;
    const chunk = 6400; // 0.2초씩
    for (var sent = 0; sent < tailBytes; sent += chunk) {
      final n = (tailBytes - sent).clamp(0, chunk);
      _send({'type': 'audio_input', 'data': base64Encode(Uint8List(n))});
    }
    _clearTurn();
    return true;
  }

  void _clearTurn() {
    _turnFrames.clear();
    _turnBytes = 0;
    _turnHasSpeech = false;
    _loudRun = 0;
    _quietBytes = 0;
    _floor = 100;
  }

  /// 말이 시작됐다고 보는 기준 — **바닥 소음 위로 이만큼**.
  ///
  /// 고정값 8로 두었더니 **차분하게 말하는 사람을 놓쳤다** (2026-09-16).
  /// 방마다 바닥 소음이 다르므로 고정값 대신 바닥에서 띄운다.
  static const _speechMargin = 4;
  static const _speechFloorMin = 4;
  static const _speechFloorMax = 10;

  int get _speechLevel =>
      (_floor + _speechMargin).clamp(_speechFloorMin, _speechFloorMax);

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
    _lastLevel = level;
    // 값이 튀지 않게 지수 평활 — 눈으로 읽을 수 있어야 한다.
    micLevel = ((micLevel * 3 + level) / 4).round();
    if (level > micPeak) micPeak = level;
  }

  /// 재생이 정말 끝나면 [done]을 부른다. 200ms마다 보고, 오래 끌지 않는다.
  ///
  /// **큐가 빈 것만으로는 끝이 아니다.** 조각과 조각 사이에도 큐는 빈다.
  /// 그래서 **[_quietFor]만큼 연속으로 조용하고, 그동안 새 조각도 오지
  /// 않아야** 끝으로 인정한다.
  void _whenQuiet(int gen, void Function() done) {
    _holdTimer?.cancel();
    var waited = Duration.zero;
    var quiet = Duration.zero;
    const step = Duration(milliseconds: 200);
    _holdTimer = Timer.periodic(step, (timer) {
      if (gen != _generation) {
        timer.cancel();
        return;
      }
      waited += step;
      final chunkAt = _lastChunkAt;
      final chunkFresh = chunkAt != null &&
          DateTime.now().difference(chunkAt) < _quietFor;
      quiet = (speaker.idle && !chunkFresh) ? quiet + step : Duration.zero;

      if (quiet >= _quietFor || waited > _holdCap) {
        timer.cancel();
        done();
      }
    });
  }

  /// 인사가 끝났다 — 이제부터 들어오는 소리는 모아 둔다.
  void _releaseMic(int gen) {
    if (gen != _generation || !_discarding) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _discarding = false;
    _clearTurn();
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
        // AI가 말을 시작하면 **그동안 모인 소리는 버린다.** 답을 기다리며
        // 낸 숨소리·스피커 에코가 다음 버튼에 실려 나가지 않게 한다.
        if (!_discarding) _clearTurn();
        // 첫 인사가 **시작됐다.** 짧은 유예를 끝까지 기다리는 쪽으로 바꾼다 —
        // 여기서 유예가 끝나 버리면 인사 도중에 마이크가 열린다 (결정 27).
        if (_discarding) {
          _holdTimer?.cancel();
          final gen = _generation;
          _holdTimer = Timer(_holdCap, () => _releaseMic(gen));
        }
        final text = _content(json);
        if (text != null) _emit(EviAssistantSpoke(text));

      case 'audio_output':
        final data = json['data'] as String?;
        if (data == null) break;
        _lastChunkAt = DateTime.now();
        try {
          speaker.enqueue(base64Decode(data));
        } on Object {
          // 조각 하나가 깨져도 대화를 끊지 않는다.
        }

      case 'assistant_end':
        // **여기서 「말을 마쳤다」고 알리지 않는다.** 이 프레임은 메시지가
        // 끝났다는 뜻이고 소리는 아직 나오는 중이다. 그대로 알리면 화면이
        // 「말하고 있습니다 → 듣고 있습니다 → 말하고 있습니다」로 깜빡인다
        // (2026-09-15 테스트). 재생이 비는 것을 보고 알린다.
        _whenQuiet(_generation, () {
          // **AI가 말을 마친 순간 그동안 모인 소리는 버린다.** AI가 말하는
          // 동안 마이크에 들어온 것은 대개 스피커 에코다 — 남겨 두면 다음에
          // 아무 말 없이 버튼을 눌러도 그 에코가 발화로 나간다. 끼어들고
          // 싶었다면 말하는 중에 버튼을 눌렀을 것이다.
          _clearTurn();
          _emit(const EviAssistantDone());
          _releaseMic(_generation);
        });

      case 'user_interruption':
        interruptions++;
        // 사용자가 끊었으면 재생을 기다릴 이유가 없다.
        _holdTimer?.cancel();
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
    if (content is! String || content.isEmpty) return null;
    final text = stripExpressionTail(content);
    return text.isEmpty ? null : text;
  }

  /// **Hume이 발화 끝에 붙이는 영문 표정 꼬리를 뗀다** (계약 v1.13 §4).
  ///
  /// ```
  /// "아 내가 이거 합격하면은 좀. {slightly doubtful, slightly calm, ...}"
  /// ```
  ///
  /// 프로소디를 못 받는 LLM을 위한 Hume 기본 동작이고 **끄는 설정이 없다.**
  /// AI서버가 CLM 쪽에서 떼지만(계약 v1.13), **같은 꼬리가 앱의 소켓으로도
  /// 온다** — 우리는 `user_message`를 직접 받는 여섯 번째 소비자다.
  ///
  /// 떼지 않으면 두 가지가 깨진다. **텍스트 채널에 음성 채널이 섞이고**
  /// (FR-025 — 앱은 프로소디를 파싱하지 않는다), 음성 종료 판정이 꼬리
  /// 때문에 말끝을 못 읽는다 (`SpokenEnd`).
  ///
  /// **영문자로 시작하는 끝의 중괄호만** 뗀다 — 사용자가 한글로 말한
  /// 중괄호는 건드리지 않는다.
  @visibleForTesting
  static String stripExpressionTail(String content) =>
      content.replaceFirst(RegExp(r'\s*\{[A-Za-z][^{}]*\}\s*$'), '').trim();

  void _fail(EviFailure reason) => _emit(EviFailed(reason));

  void _emit(EviEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}
