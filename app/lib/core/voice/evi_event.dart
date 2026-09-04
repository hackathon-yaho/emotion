/// EVI 소켓에서 화면으로 올려보내는 사건들.
///
/// **여기 프로소디가 없다.** Hume은 `user_message`에 48종 점수를 실어 보내지만
/// 앱은 그걸 **파싱하지도 않는다** — 화면에 감정 수치를 그리지 않고(FR-030·031),
/// 분석은 AI서버가 Hume에서 직접 받는다. 앱이 들고 있으면 언젠가 화면에
/// 나온다.
sealed class EviEvent {
  const EviEvent();
}

/// 소켓이 열리고 `chat_metadata`가 도착했다.
///
/// [chatGroupId]가 F2-07 이어하기의 `resumedChatGroupId` 원천이다
/// (`docs/request/app/chat-group-id.md`).
class EviConnected extends EviEvent {
  const EviConnected({this.chatGroupId, this.chatId});

  final String? chatGroupId;
  final String? chatId;
}

/// 사용자 발화가 텍스트로 확정됐다.
///
/// 화면은 이것을 **잠깐만** 보여준다 (design-system §6-1 절충안) — 대화 내용을
/// 계속 쌓아 보여주면 채팅앱이 되고, 말하는 데 집중이 안 된다.
class EviUserSpoke extends EviEvent {
  const EviUserSpoke(this.text);

  final String text;
}

/// AI 발화 텍스트. **자막으로 그리지 않는다** — 음성으로 듣는다 (§6-1).
/// 화면 상태(말하고 있습니다)를 바꾸는 신호로만 쓴다.
class EviAssistantSpoke extends EviEvent {
  const EviAssistantSpoke(this.text);

  final String text;
}

/// AI 발화가 끝났다 (`assistant_end`).
class EviAssistantDone extends EviEvent {
  const EviAssistantDone();
}

/// 사용자가 AI 말을 끊었다 (`user_interruption`). 재생을 즉시 멈춘다.
class EviUserInterruption extends EviEvent {
  const EviUserInterruption();
}

/// 소켓이 닫혔다 — 정상 종료 포함.
class EviClosed extends EviEvent {
  const EviClosed();
}

/// 실패. **원인별로 화면 문구가 갈린다** (F2-04, design-system §7-1).
class EviFailed extends EviEvent {
  const EviFailed(this.reason);

  final EviFailure reason;
}

/// F2-04의 세 분기 + 그 외.
enum EviFailure {
  /// 마이크 권한 거부·장치 없음. **사용자가 고칠 수 있는 유일한 경우**라
  /// 안내 문구가 다르다.
  micDenied,

  /// 토큰 만료·잘못된 Config — 우리 잘못이다. 사용자에게 원인을 말하지 않고
  /// 다시 시도만 제안한다.
  auth,

  /// 연결이 끊겼다.
  network,

  /// 그 외. 분류하지 못한 것을 auth로 뭉개지 않는다.
  unknown,
}
