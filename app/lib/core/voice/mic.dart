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
  RecordMic([this._factory = AudioRecorder.new]);

  final AudioRecorder Function() _factory;

  /// **대화마다 새로 만든다.**
  ///
  /// 한때 `AudioRecorder`를 하나 만들어 앱 수명 내내 들고 있었는데,
  /// [close]가 그것을 `dispose()`했다. 프로바이더는 같은 [RecordMic]을 계속
  /// 주므로 **두 번째 대화가 죽은 레코더로 시작**했다 — 2026-09-06 실사용에서
  /// "첫 대화 이후 계속 연결이 끊어졌다"로 드러났다.
  AudioRecorder? _rec;

  @override
  Future<Stream<Uint8List>> open() async {
    await close();
    final rec = _rec = _factory();
    if (!await rec.hasPermission()) throw const MicDenied();
    return rec.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: Mic.sampleRate,
        numChannels: Mic.channels,
        // **에코 제거를 켠다.** 스피커로 나가는 AI 목소리를 마이크가 다시
        // 주우면 Hume이 "사용자가 말한다"로 보고 **자기 말을 끊는다** —
        // 2026-09-06 실사용에서 "AI 말이 자꾸 끊긴다"로 드러났다.
        //
        // 이 값들은 웹에서 `getUserMedia` 제약으로 그대로 넘어간다. 셋 다
        // 기본이 `false`라 **명시적으로 끄고 있었다** — 브라우저 기본값(켜짐)
        // 보다 나쁜 상태였다.
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    final rec = _rec;
    if (rec == null) return;
    _rec = null;
    // `stop()`이 경로를 돌려주지만 스트림 모드에서는 파일이 없다.
    await rec.stop();
    await rec.dispose();
  }
}
