import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

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

  static Uri _defaultEndpoint(Map<String, String> query) => Uri(
        scheme: 'wss',
        host: 'api.hume.ai',
        path: '/v0/evi/chat',
        queryParameters: query,
      );

  final _events = StreamController<EviEvent>.broadcast();
  Stream<EviEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _closing = false;

  /// 연결. **소켓을 먼저 열고 마이크를 나중에 켠다** — 순서를 뒤집으면 인증
  /// 실패인데도 마이크 권한 창이 먼저 떠서 사용자가 원인을 오해한다.
  Future<void> start({
    required String accessToken,
    required String configId,
    required String sessionId,
    String? resumedChatGroupId,
  }) async {
    _closing = false;
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
        _onFrame,
        onError: (_) => _fail(EviFailure.network),
        onDone: () {
          if (!_closing) _emit(const EviClosed());
        },
      );

      // 오디오 형식을 먼저 알린다. 이걸 보내기 전에 오디오를 밀면 Hume이
      // 기본값으로 해석해 알아듣지 못한다.
      _send({
        'type': 'session_settings',
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
      _micSub = bytes.listen(
        _sendAudio,
        onError: (_) => _fail(EviFailure.micDenied),
      );
    } on MicDenied {
      _fail(EviFailure.micDenied);
    } on Object {
      _fail(EviFailure.micDenied);
    }
  }

  /// 종료. **끊는 것 자체가 실패해도 조용히 끝낸다** — 대화는 이미 끝났다.
  Future<void> stop() async {
    _closing = true;
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

  void _sendAudio(Uint8List pcm) =>
      _send({'type': 'audio_input', 'data': base64Encode(pcm)});

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

      case 'user_interruption':
        // 큐를 비우지 않으면 사용자가 끊었는데도 AI가 계속 말한다.
        speaker.stop().catchError((_) {});
        _emit(const EviUserInterruption());

      case 'error':
        // Hume의 오류 문구를 사용자에게 그대로 보여주지 않는다. 인증 계열만
        // 갈라내고 나머지는 unknown이다 — 분류하지 못한 것을 auth로 뭉개면
        // "다시 시도"가 소용없는 상황에서도 다시 시도를 권하게 된다.
        final slug = (json['slug'] ?? json['code'] ?? '').toString();
        _fail(slug.contains('auth') || slug.contains('token')
            ? EviFailure.auth
            : EviFailure.unknown);
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
