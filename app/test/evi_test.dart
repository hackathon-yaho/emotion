import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:voice_journal/core/providers.dart';
import 'package:voice_journal/core/voice/evi_event.dart';
import 'package:voice_journal/core/voice/evi_service.dart';
import 'package:record/record.dart';

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

  // 닫힘 코드는 진단용이다 — 대역에서는 없다.
  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

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

  /// **열 때마다 새 스트림.** 실제 `RecordMic`도 대화마다 레코더를 새로
  /// 만든다 — 하나를 재사용하면 두 번째 `listen`에서 죽어, 테스트가 제품에
  /// 없는 실패를 만든다.
  StreamController<Uint8List>? _bytes;
  bool opened = false;
  bool closedMic = false;

  void speak(List<int> pcm) => _bytes?.add(Uint8List.fromList(pcm));

  @override
  Future<Stream<Uint8List>> open() async {
    if (denied) throw const MicDenied();
    opened = true;
    final c = _bytes = StreamController<Uint8List>();
    return c.stream;
  }

  @override
  Future<void> close() async {
    closedMic = true;
    await _bytes?.close();
    _bytes = null;
  }
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

    test('custom_session_id를 session_settings로도 보낸다 (계약 §4)', () async {
      // **쿼리로만 보내면 Hume이 CLM 호출에 세션 id를 싣지 않는다.** 그러면
      // AI서버가 fail-closed로 401을 주고 Hume은 채팅을 끝내는데, 앱에는
      // `closed 1000`으로 보여 원인이 안 보인다 (2026-09-06).
      await start();
      final first = jsonDecode(channel.sent.first) as Map<String, dynamic>;
      expect(first['custom_session_id'], 'sess-uuid');
      expect(opened.queryParameters['custom_session_id'], 'sess-uuid',
          reason: '쿼리에도 계속 싣는다 — 어느 쪽을 읽든 걸리지 않게');
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

    test('홀수 길이 조각에도 죽지 않고 소리 크기를 잰다 (진단)', () async {
      await start();
      // 조용한 조각 → 0. 홀수 길이여도 던지지 않는다.
      mic.speak(List<int>.filled(401, 0));
      await settle();
      expect(evi.micPeak, 0);
      // 큰 조각 → 0보다 크게.
      final loud = Int16List(400);
      for (var i = 0; i < loud.length; i++) {
        loud[i] = i.isEven ? 12000 : -12000;
      }
      mic.speak(Uint8List.sublistView(loud));
      await settle();
      expect(evi.micPeak, greaterThan(0));
      expect(
        channel.sent
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .where((m) => m['type'] == 'audio_input'),
        hasLength(2),
      );
    });

    // 이 서비스는 앱 수명 내내 사는 한 개짜리다(`eviServiceProvider`).
    // 계수기를 안 지우면 **두 번째 대화 화면에 첫 대화의 턴 수가 얹힌다**.
    test('새 연결은 계수기를 0에서 시작한다', () async {
      await start();
      channel.push({
        'type': 'assistant_message',
        'message': {'role': 'assistant', 'content': '네'}
      });
      channel.push({'type': 'user_interruption'});
      final loud = Int16List(200)..fillRange(0, 200, 9000);
      mic.speak(Uint8List.sublistView(loud));
      await settle();
      expect(evi.assistantTurns, 1);
      expect(evi.interruptions, 1);
      expect(evi.micPeak, greaterThan(0));

      await start(); // 두 번째 대화
      await settle();
      expect(evi.assistantTurns, 0);
      expect(evi.interruptions, 0);
      expect(evi.micPeak, 0);
      expect(evi.micLevel, 0);
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
      // `start()`가 앞선 연결을 정리하며 스피커도 한 번 멈춘다 — 여기서
      // 보는 것은 **끼어들기 때문에 한 번 더 멈췄는가**다.
      final before = speaker.stops;
      channel.push({'type': 'user_interruption'});
      await settle();
      expect(speaker.stops, before + 1);
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

    test('E0700은 busy다 — 이어하기에서 새 세션을 만들면 안 되는 신호', () async {
      // 계약 §2-14: 정원이 찬 순간에 이어하기하면 소켓에서 이 오류가 온다.
      // 새로 시작하면 중단된 세션이 닫혀 이어할 대화가 사라진다.
      await start();
      channel.push({'type': 'error', 'slug': 'E0700'});
      await settle();
      expect(events.whereType<EviFailed>().last.reason, EviFailure.busy);
    });

    test('코드가 없어도 문구로 잡는다 — 슬러그는 바뀔 수 있다', () async {
      await start();
      channel.push({
        'type': 'error',
        'message': 'You have too many active chats associated with your account',
      });
      await settle();
      expect(events.whereType<EviFailed>().last.reason, EviFailure.busy);
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

  group('서비스 수명 (2026-09-06 회귀)', () {
    // **한때 `eviServiceProvider`가 `autoDispose`였다.** 화면이 `ref.read`로
    // 집으면 듣는 사람이 없어 **읽자마자 폐기**됐고, `dispose()`가
    // `mic.close()`를 불러 레코더를 죽였다. 그 뒤 `startStream`이 실패하는데
    // 이벤트 스트림도 이미 닫혀 있어 **화면은 실패조차 듣지 못하고 "듣고
    // 있습니다"로 남았다** — 마이크가 조용한 채 대화가 흘러가는 모양이다.
    //
    // 가짜 EVI 서버로 잡았다. 소켓은 붙고 `session_settings`도 갔는데
    // `audio_input`이 한 프레임도 오지 않았다.
    test('read만 해도 인스턴스가 살아 있고 다시 읽으면 같은 것이다', () async {
      final container = ProviderContainer(overrides: [
        micProvider.overrideWithValue(_FakeMic()),
        speakerProvider.overrideWithValue(_FakeSpeaker()),
      ]);
      addTearDown(container.dispose);

      final first = container.read(eviServiceProvider);
      await Future<void>.delayed(Duration.zero);
      final second = container.read(eviServiceProvider);

      expect(identical(first, second), isTrue);
      // 폐기됐다면 이벤트 스트림이 닫혀 있다.
      expect(first.events.isBroadcast, isTrue);
      await expectLater(
        first.events.timeout(const Duration(milliseconds: 20),
            onTimeout: (sink) => sink.close()).toList(),
        completes,
      );
    });
  });

  group('마이크 수명 (2026-09-06 실사용 회귀)', () {
    // **첫 대화 이후 계속 연결이 끊어졌다.** `RecordMic`이 `AudioRecorder`를
    // 하나 만들어 앱 수명 내내 들고 있었는데 `close()`가 그것을 폐기했고,
    // 프로바이더는 같은 `RecordMic`을 계속 주므로 **두 번째 대화가 죽은
    // 레코더로 시작**했다.
    test('대화마다 레코더를 새로 만든다', () async {
      var made = 0;
      final mic = RecordMic(() {
        made++;
        return AudioRecorder();
      });

      // 테스트 환경에는 플러그인이 없어 `open()`은 실패한다 — 우리가 보는
      // 것은 **레코더를 새로 만들었는가**다.
      for (var i = 0; i < 2; i++) {
        try {
          await mic.open();
        } on Object {
          // 플러그인 없음
        }
      }

      expect(made, 2, reason: '두 번째 대화도 자기 레코더를 가져야 한다');
    });
  });

  group('연결 세대 (2026-09-06 실사용 회귀)', () {
    // **"첫 대화 이후 계속 연결이 끊어진다"의 실제 원인.**
    //
    // `EviService`는 인스턴스 하나를 앱 내내 쓴다. 그런데 `start()`가 이전
    // 연결을 닫지 않고 `_channel`을 덮어써서, **옛 소켓이 살아남아 나중에
    // 닫힐 때 그 `onDone`이 새 대화 화면을 "연결이 끊어졌습니다"로** 만들었다.
    // 사용자는 "이전 대화가 남아 있는 것 같다"고 했고 정확했다.
    test('옛 연결이 늦게 닫혀도 새 대화를 끊지 않는다', () async {
      final first = _FakeChannel();
      final second = _FakeChannel();
      final channels = <_FakeChannel>[first, second];
      final mic = _FakeMic();
      final evi = EviService(
        mic: mic,
        speaker: _FakeSpeaker(),
        connect: (_) => channels.removeAt(0),
      );
      final seen = <EviEvent>[];
      evi.events.listen(seen.add);

      await evi.start(accessToken: 't', configId: 'c', sessionId: 's1');
      await evi.stop();
      await evi.start(accessToken: 't', configId: 'c', sessionId: 's2');
      seen.clear();

      // 첫 소켓이 이제서야 닫힌다 — 새 대화는 멀쩡해야 한다.
      first.hangUp();
      await Future<void>.delayed(Duration.zero);

      expect(seen.whereType<EviClosed>(), isEmpty,
          reason: '옛 연결의 닫힘이 새 대화를 끊으면 안 된다');
      expect(seen.whereType<EviFailed>(), isEmpty);
    });

    test('새로 시작하면 이전 소켓을 먼저 닫는다', () async {
      final first = _FakeChannel();
      final second = _FakeChannel();
      final channels = <_FakeChannel>[first, second];
      final evi = EviService(
        mic: _FakeMic(),
        speaker: _FakeSpeaker(),
        connect: (_) => channels.removeAt(0),
      );

      await evi.start(accessToken: 't', configId: 'c', sessionId: 's1');
      await evi.start(accessToken: 't', configId: 'c', sessionId: 's2');

      expect(first.closed, isTrue, reason: '이전 소켓이 남아 있으면 안 된다');
      expect(second.closed, isFalse);
    });

    test('옛 소켓의 프레임이 새 대화에 섞이지 않는다', () async {
      final first = _FakeChannel();
      final second = _FakeChannel();
      final channels = <_FakeChannel>[first, second];
      final evi = EviService(
        mic: _FakeMic(),
        speaker: _FakeSpeaker(),
        connect: (_) => channels.removeAt(0),
      );
      final seen = <EviEvent>[];
      evi.events.listen(seen.add);

      await evi.start(accessToken: 't', configId: 'c', sessionId: 's1');
      await evi.start(accessToken: 't', configId: 'c', sessionId: 's2');
      seen.clear();

      first.push({
        'type': 'user_message',
        'message': {'role': 'user', 'content': '이전 대화의 발화'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty, reason: '옛 소켓의 발화가 새 화면에 뜨면 안 된다');
    });
  });

  group('재생 큐 (2026-09-06 실사용 회귀)', () {
    // **"AI가 혼자 말하다 혼자 끊긴다".** 조각 하나의 완료 신호를 놓치면
    // 큐가 그대로 멈춰 남은 말이 영영 안 나온다. WAV 길이를 읽어 시계를
    // 걸어 두면, 신호가 안 와도 다음 조각으로 넘어간다.
    Uint8List wav({required int millis, int rate = 16000}) {
      final bytes = (rate * 2 * millis / 1000).round();
      final b = BytesBuilder()
        ..add(ascii.encode('RIFF'))
        ..add(_u32(36 + bytes))
        ..add(ascii.encode('WAVE'))
        ..add(ascii.encode('fmt '))
        ..add(_u32(16))
        ..add(_u16(1)) // PCM
        ..add(_u16(1)) // mono
        ..add(_u32(rate))
        ..add(_u32(rate * 2)) // byte rate
        ..add(_u16(2))
        ..add(_u16(16))
        ..add(ascii.encode('data'))
        ..add(_u32(bytes))
        ..add(Uint8List(bytes));
      return b.toBytes();
    }

    test('WAV 길이를 읽어낸다 — 시계의 근거', () {
      expect(
        AudioPlayersSpeaker.debugWavDuration(wav(millis: 400)),
        const Duration(milliseconds: 400),
      );
    });

    test('WAV가 아니면 시계를 걸지 않는다 — 억지로 끊지 않는다', () {
      expect(
        AudioPlayersSpeaker.debugWavDuration(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });
  });
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
