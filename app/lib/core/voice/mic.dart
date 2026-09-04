import 'dart:typed_data';

import 'package:record/record.dart';

import 'evi_event.dart';

/// 마이크. 테스트에서 갈아끼울 수 있게 인터페이스로 둔다.
///
/// **파일로 쓰지 않는다.** `startStream`은 바이트를 그대로 흘려주므로 녹음
/// 파일이 생기지 않는다 — FR-041("음성 원본을 서버에 받지도 저장하지도
/// 않는다")의 앱 쪽 대응이다. `start(path:)` 계열을 쓰면 그 순간 규칙이
/// 깨진다.
abstract interface class Mic {
  /// EVI가 요구하는 형식 — 16kHz · 모노 · PCM16.
  static const sampleRate = 16000;
  static const channels = 1;

  /// PCM16 바이트 스트림. 권한이 없으면 [MicDenied]를 던진다.
  Future<Stream<Uint8List>> open();

  Future<void> close();
}

/// 권한 거부·장치 없음. [EviFailure.micDenied]로 옮겨진다.
class MicDenied implements Exception {
  const MicDenied();
}

class RecordMic implements Mic {
  RecordMic([AudioRecorder? recorder]) : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;

  @override
  Future<Stream<Uint8List>> open() async {
    if (!await _rec.hasPermission()) throw const MicDenied();
    return _rec.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: Mic.sampleRate,
        numChannels: Mic.channels,
      ),
    );
  }

  @override
  Future<void> close() async {
    // `stop()`이 경로를 돌려주지만 스트림 모드에서는 파일이 없다.
    await _rec.stop();
    await _rec.dispose();
  }
}
