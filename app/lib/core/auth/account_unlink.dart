import '../auth/kakao_login.dart';
import '../data/journal_repository.dart';
import '../storage/token_storage.dart';

/// 탈퇴 왕복의 결과 (F10-03 · 계약 v1.6 §2-3).
enum UnlinkOutcome {
  /// 탈퇴 왕복이 아니다 — 평범한 실행이다.
  none,

  /// 카카오 동의 화면에서 사용자가 되돌아왔다. **아무것도 지우지 않는다.**
  cancelled,

  /// 지웠다. 기기를 비우고 처음 화면으로 돌아가야 한다.
  done,

  /// 서버가 지우지 못했다. **기기를 비우지 않는다** — 비우면 다시 요청할
  /// 방법이 없어진다.
  failed,
}

/// 카카오에서 돌아왔을 때, 그 인가 코드가 **탈퇴용이면** 탈퇴를 끝낸다.
///
/// 웹은 인가 페이지로 나갔다가 앱이 새로 뜬다. 돌아온 주소만 봐서는 그 코드가
/// 로그인용인지 탈퇴용인지 구별할 수 없으므로, 나가기 전에 저장소에 적어 둔
/// 표시로 가른다 (`TokenStorage.markPendingUnlink`).
///
/// **표시는 먼저 지운다.** 남겨 두면 실패했을 때 다음 로그인 복귀가 그 코드를
/// 다시 탈퇴로 오해한다.
Future<UnlinkOutcome> finishUnlinkIfReturned({
  required TokenStorage storage,
  required JournalRepository repo,
  required Uri here,
}) async {
  if (!await storage.readPendingUnlink()) return UnlinkOutcome.none;
  await storage.clearPendingUnlink();

  // 동의 화면에서 취소했거나 코드 없이 돌아왔다. **취소는 탈퇴 중단이다** —
  // 여기서 데이터만 지우면 사용자가 그만두려던 일을 대신 해버리는 셈이다.
  if (KakaoLogin.deniedIn(here)) return UnlinkOutcome.cancelled;
  final code = KakaoLogin.codeFrom(here);
  if (code == null) return UnlinkOutcome.cancelled;

  try {
    await repo.deleteAccount(
      kakaoAuthCode: code,
      // **인가 때 쓴 것과 같은 값이어야 한다** — 카카오가 대조한다.
      redirectUri: KakaoLogin.redirectUriFrom(here).toString(),
    );
    return UnlinkOutcome.done;
  } on Object {
    return UnlinkOutcome.failed;
  }
}
