import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// AI 음성 재생. 테스트에서 갈아끼울 수 있게 인터페이스로 둔다.
///
/// EVI는 `audio_output`을 **여러 조각으로 나눠** 보내므로 큐가 필요하다. 조각을
/// 받는 대로 재생하면 겹쳐서 들린다.
abstract interface class Speaker {
  /// 조각 하나를 큐에 넣는다. 재생 중이면 끝난 뒤에 이어 재생한다.
  void enqueue(Uint8List wav);

  /// 지금 재생과 **큐에 남은 것 전부** 버린다.
  ///
  /// 사용자가 말을 끊었을 때(`user_interruption`) 부른다 — 큐를 비우지 않으면
  /// 사용자가 끊었는데도 AI가 계속 말한다.
  Future<void> stop();

  Future<void> dispose();
}

class AudioPlayersSpeaker implements Speaker {
  AudioPlayersSpeaker([AudioPlayer? player]) : _player = player ?? AudioPlayer() {
    _sub = _player.onPlayerComplete.listen((_) {
      _playing = false;
      _pump();
    });
  }

  final AudioPlayer _player;
  late final StreamSubscription<void> _sub;
  final Queue<Uint8List> _queue = Queue<Uint8List>();
  bool _playing = false;

  @override
  void enqueue(Uint8List wav) {
    _queue.add(wav);
    _pump();
  }

  void _pump() {
    if (_playing || _queue.isEmpty) return;
    _playing = true;
    final chunk = _queue.removeFirst();
    // EVI는 조각마다 완결된 WAV를 보낸다.
    _player.play(BytesSource(chunk, mimeType: 'audio/wav')).catchError((_) {
      // 한 조각을 못 재생해도 대화를 끊지 않는다 — 다음 조각으로 넘어간다.
      _playing = false;
      _pump();
    });
  }

  @override
  Future<void> stop() async {
    _queue.clear();
    _playing = false;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    _queue.clear();
    await _player.dispose();
  }
}
