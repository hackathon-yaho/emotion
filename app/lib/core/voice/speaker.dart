import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// AI 음성 재생. 테스트에서 갈아끼울 수 있게 인터페이스로 둔다.
///
/// EVI는 `audio_output`을 **여러 조각으로 나눠** 보내므로 큐가 필요하다. 조각을
/// 받는 대로 재생하면 겹쳐서 들린다.
abstract interface class Speaker {
  /// 조각 하나를 큐에 넣는다. 재생 중이면 끝난 뒤에 이어 재생한다.
  void enqueue(Uint8List wav);

  /// 지금 소리를 내고 있지 않고 큐도 비었는지.
  ///
  /// 첫 인사가 **스피커에서 다 나온 뒤에** 마이크를 여는 판단에 쓴다. Hume의
  /// `assistant_end`는 조각을 다 보냈다는 뜻일 뿐이라, 그 시점에 열면 남은
  /// 재생이 마이크로 되돌아가 **자기 말을 끊는다.**
  bool get idle;

  /// 지금 재생과 **큐에 남은 것 전부** 버린다.
  ///
  /// 사용자가 말을 끊었을 때(`user_interruption`) 부른다 — 큐를 비우지 않으면
  /// 사용자가 끊었는데도 AI가 계속 말한다.
  Future<void> stop();

  Future<void> dispose();
}

class AudioPlayersSpeaker implements Speaker {
  AudioPlayersSpeaker([AudioPlayer? player])
      : _player = player ?? AudioPlayer() {
    _sub = _player.onPlayerComplete.listen((_) => _finish());
  }

  final AudioPlayer _player;
  late final StreamSubscription<void> _sub;
  final Queue<Uint8List> _queue = Queue<Uint8List>();
  bool _playing = false;

  /// **완료 신호를 못 받았을 때를 대비한 시계.**
  ///
  /// 조각 하나가 끝났다는 신호를 한 번이라도 놓치면 큐가 그대로 멈추고,
  /// **AI가 말하다 만 것처럼 들린다** — 2026-09-06 실사용에서 "혼자 말하다
  /// 혼자 끊긴다"로 나왔다. WAV 헤더가 길이를 알려주므로, 그 시간이 지나도
  /// 신호가 없으면 다음 조각으로 넘어간다.
  Timer? _watchdog;

  /// 진단용 — 받은 조각 수. `SHOW_ERROR_DETAIL`에서만 화면에 쓴다.
  int received = 0;

  /// 재생 세대. [stop]마다 오른다.
  ///
  /// **`play()`는 비동기라 멈춘 뒤에 시작될 수 있다.** 대화를 끝내고 요약
  /// 화면으로 넘어갔는데 **AI 목소리가 뒤늦게 흘러나오는 일**이 실제로 있었다
  /// (2026-09-15 테스트 — 첫 인사말이 요약 화면에서 들렸다). 재생이 시작된
  /// 시점에 세대가 달라져 있으면 그 자리에서 다시 멈춘다.
  int _generation = 0;

  @override
  bool get idle => !_playing && _queue.isEmpty;

  @override
  void enqueue(Uint8List wav) {
    received++;
    _queue.add(wav);
    _pump();
  }

  void _pump() {
    if (_playing || _queue.isEmpty) return;
    _playing = true;
    final chunk = _queue.removeFirst();

    _watchdog?.cancel();
    final length = _wavDuration(chunk);
    if (length != null) {
      _watchdog = Timer(length + const Duration(milliseconds: 250), _finish);
    }

    // EVI는 조각마다 완결된 WAV를 보낸다.
    final gen = _generation;
    _player.play(BytesSource(chunk, mimeType: 'audio/wav')).then((_) {
      // 그사이 멈췄다면 지금 시작된 소리를 다시 멈춘다.
      if (gen != _generation) _player.stop().catchError((_) {});
    }).catchError((_) {
      // 한 조각을 못 재생해도 대화를 끊지 않는다 — 다음 조각으로 넘어간다.
      _finish();
    });
  }

  void _finish() {
    _watchdog?.cancel();
    _watchdog = null;
    if (!_playing) return;
    _playing = false;
    _pump();
  }

  /// WAV 헤더에서 재생 길이를 읽는다. 모양이 다르면 null.
  ///
  /// `data` 청크의 바이트 수 ÷ (샘플레이트 × 채널 × 바이트/샘플).
  /// 테스트가 보는 입구.
  @visibleForTesting
  static Duration? debugWavDuration(Uint8List wav) => _wavDuration(wav);

  static Duration? _wavDuration(Uint8List wav) {
    if (wav.length < 44) return null;
    final b = ByteData.sublistView(wav);
    // "RIFF" .... "WAVE"
    if (b.getUint32(0, Endian.big) != 0x52494646) return null;
    if (b.getUint32(8, Endian.big) != 0x57415645) return null;

    var offset = 12;
    int? byteRate;
    while (offset + 8 <= wav.length) {
      final id = b.getUint32(offset, Endian.big);
      final size = b.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 0x666D7420 && body + 16 <= wav.length) {
        // "fmt " — 초당 바이트 수가 28번째 바이트에 있다.
        byteRate = b.getUint32(body + 8, Endian.little);
      } else if (id == 0x64617461) {
        // "data"
        if (byteRate == null || byteRate == 0) return null;
        final bytes = size == 0 ? wav.length - body : size;
        return Duration(milliseconds: (bytes * 1000 / byteRate).round());
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  @override
  Future<void> stop() async {
    _generation++;
    _watchdog?.cancel();
    _watchdog = null;
    _queue.clear();
    _playing = false;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _watchdog?.cancel();
    await _sub.cancel();
    _queue.clear();
    await _player.dispose();
  }
}
