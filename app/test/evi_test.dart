import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:voice_journal/core/voice/evi_event.dart';
import 'package:voice_journal/core/voice/evi_service.dart';
import 'package:voice_journal/core/voice/mic.dart';
import 'package:voice_journal/core/voice/speaker.dart';

/// 소켓 대역 — 서버가 보낸 프레임을 우리가 밀어넣고, 앱이 보낸 것을 받는다.
///
/// `WebSocketChannel`을 직접 구현한다. `stream_channel`을 테스트 의존성으로
/// 추가하지 않으려는 것이다 — 우리가 쓰는 것은 `stream`과 `sink` 둘뿐이다.
class _FakeChannel implements WebSocketChannel {
  _FakeChannel();

  final _fromServer = StreamController<dynamic>();
  final sent = <String>[];
  bool closed = false;

  void push(Map<String, Object?> frame) => _fromServer.add(jsonEncode(frame));
  void breakDown() => _fromServer.addError('boom');
  void hangUp() => _fromServer.close();

  @override
  Stream<dynamic> get stream => _fromServer.stream;

  @override
  WebSocketSink get sink => _Sink(this);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  _Sink(this.owner);

  final _FakeChannel owner;

  @override
  void add(dynamic data) => owner.sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    owner.closed = true;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMic implements Mic {
  _FakeMic({this.denied = false});

  final bool denied;
  final _bytes = StreamController<Uint8List>();
  bool opened = false;
  bool closedMic = false;

  void speak(List<int> pcm) => _bytes.add(Uint8List.fromList(pcm));

  @override
  Future<Stream<Uint8List>> open() async {
    if (denied) throw const MicDenied();
    opened = true;
    return _bytes.stream;
  }

  @override
  Future<void> close() async => closedMic = true;
}

class _FakeSpeaker implements Speaker {
  final played = <Uint8List>[];
  int stops = 0;

  @override
  void enqueue(Uint8List wav) => played.add(wav);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeChannel channel;
  late _FakeMic mic;
  late _FakeSpeaker speaker;
  late EviService evi;
  late List<EviEvent> events;
  late Uri opened;

  setUp(() {
    channel = _FakeChannel();
    mic = _FakeMic();
    speaker = _FakeSpeaker();
    evi = EviService(
      mic: mic,
      speaker: speaker,
      connect: (uri) {
        opened = uri;
        return channel;
      },
    );
    events = [];
    evi.events.listen(events.add);
  });

  Future<void> start() => evi.start(
        accessToken: 'short-lived',
        configId: 'cfg_1',
        sessionId: 'sess-uuid',
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('핸드셰이크 (spec F2-02 · 계약 §4)', () {
    test('토큰·Config·custom_session_id를 쿼리로 넘긴다', () async {
      await start();
      expect(opened.scheme, 'wss');
      expect(opened.host, 'api.hume.ai');
      expect(opened.path, '/v0/evi/chat');
      expect(opened.queryParameters['access_token'], 'short-lived');
      expect(opened.queryParameters['config_id'], 'cfg_1');
      expect(opened.queryParameters['custom_session_id'], 'sess-uuid');
    });

    test('이어하기가 아니면 resumed_chat_group_id를 넣지 않는다', () async {
      await start();
      expect(opened.queryParameters.containsKey('resumed_chat_group_id'), isFalse);
    });

    test('이어하기면 넣는다 — 맥락 복원 (F2-07)', () async {
      await evi.start(
        accessToken: 't',
        configId: 'c',
        sessionId: 's',
        resumedChatGroupId: 'cg_1',
      );
      expect(opened.queryParameters['resumed_chat_group_id'], 'cg_1');
    });

    test('오디오 형식을 먼저 보낸다 — 보내기 전에 밀면 못 알아듣는다', () async {
      await start();
      final first = jsonDecode(channel.sent.first) as Map<String, dynamic>;
      expect(first['type'], 'session_settings');
      expect((first['audio'] as Map)['encoding'], 'linear16');
      expect((first['audio'] as Map)['sample_rate'], 16000);
    });

    test('language_model_api_key를 절대 보내지 않는다 (계약 §4 · 웹 번들 노출)', () async {
      await start();
      mic.speak([1, 2, 3]);
      await settle();
      expect(channel.sent.join(), isNot(contains('language_model_api_key')));
    });
  });

  group('마이크', () {
    test('PCM을 base64 audio_input으로 보낸다', () async {
      await start();
      mic.speak([0, 1, 2, 3]);
      await settle();
      final audio = channel.sent
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .where((m) => m['type'] == 'audio_input')
          .toList();
      expect(audio, hasLength(1));
      expect(base64Decode(audio.single['data'] as String), [0, 1, 2, 3]);
    });

    test('권한 거부는 예외가 아니라 micDenied 사건이다 (F2-04)', () async {
      final denied = EviService(
        mic: _FakeMic(denied: true),
        speaker: speaker,
        connect: (_) => channel,
      );
      final seen = <EviEvent>[];
      denied.events.listen(seen.add);
      await denied.start(accessToken: 't', configId: 'c', sessionId: 's');
      await settle();
      expect(seen.whereType<EviFailed>().single.reason, EviFailure.micDenied);
    });
  });

  group('수신', () {
    test('chat_metadata에서 chat_group_id를 꺼낸다 (F2-07 원천)', () async {
      await start();
      channel.push({
        'type': 'chat_metadata',
        'chat_group_id': 'cg_9',
        'chat_id': 'chat_9',
      });
      await settle();
      final e = events.whereType<EviConnected>().single;
      expect(e.chatGroupId, 'cg_9');
      expect(e.chatId, 'chat_9');
    });

    test('user_message에서 텍스트만 꺼낸다 — 프로소디를 읽지 않는다', () async {
      await start();
      channel.push({
        'type': 'user_message',
        'message': {'role': 'user', 'content': '오늘 완전 괜찮았어요'},
        'models': {
          'prosody': {
            'scores': {'Tiredness': 0.71, 'Sadness': 0.42},
          },
        },
      });
      await settle();
      final spoke = events.whereType<EviUserSpoke>().single;
      expect(spoke.text, '오늘 완전 괜찮았어요');
      // 사건에 점수를 담을 자리가 없다 — 담기면 언젠가 화면에 나온다.
      expect(spoke.toString(), isNot(contains('0.71')));
    });

    test('audio_output은 스피커 큐로 간다', () async {
      await start();
      channel.push({'type': 'audio_output', 'data': base64Encode([9, 9])});
      await settle();
      expect(speaker.played.single, [9, 9]);
    });

    test('user_interruption은 재생을 즉시 버린다', () async {
      await start();
      channel.push({'type': 'user_interruption'});
      await settle();
      expect(speaker.stops, 1);
      expect(events.whereType<EviUserInterruption>(), hasLength(1));
    });

    test('깨진 프레임 하나로 대화를 끊지 않는다', () async {
      await start();
      channel.sink;
      channel.push({'type': 'audio_output'}); // data 없음
      channel.push({'type': 'user_message'}); // message 없음
      channel.push({'type': '모르는_타입'});
      await settle();
      expect(events.whereType<EviFailed>(), isEmpty);
      expect(events.whereType<EviClosed>(), isEmpty);
    });

    test('인증 오류와 그 외를 갈라낸다 — 분류 못 한 것을 auth로 뭉개지 않는다', () async {
      await start();
      channel.push({'type': 'error', 'slug': 'invalid_token'});
      await settle();
      expect(events.whereType<EviFailed>().last.reason, EviFailure.auth);

      channel.push({'type': 'error', 'slug': 'something_else'});
      await settle();
      expect(events.whereType<EviFailed>().last.reason, EviFailure.unknown);
    });

    test('소켓 오류는 network 실패다', () async {
      await start();
      channel.breakDown();
      await settle();
      expect(events.whereType<EviFailed>().single.reason, EviFailure.network);
    });

    test('서버가 끊으면 closed', () async {
      await start();
      channel.hangUp();
      await settle();
      expect(events.whereType<EviClosed>(), hasLength(1));
    });
  });

  group('종료', () {
    test('마이크·스피커·소켓을 다 닫는다', () async {
      await start();
      await evi.stop();
      expect(mic.closedMic, isTrue);
      expect(speaker.stops, greaterThan(0));
      expect(channel.closed, isTrue);
    });

    test('우리가 끊은 경우에는 closed를 올리지 않는다 — 오류로 보이면 안 된다', () async {
      await start();
      await evi.stop();
      channel.hangUp();
      await settle();
      expect(events.whereType<EviClosed>(), isEmpty);
    });
  });
}
