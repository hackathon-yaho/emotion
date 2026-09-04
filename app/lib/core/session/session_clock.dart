/// 세션 길이 계산 (spec F2-03 · design-system §7 결정 1).
///
/// **서버가 준 `hardCutSec`을 쓰고 앱에 상수로 박지 않는다** (계약 §2-4).
/// 이어하기는 남은 시간이 그대로 들어온다 — 새 7분을 주지 않는다 (NFR-06).
///
/// 소프트 랩(5분)에는 **화면이 아무것도 하지 않는다.** AI가 말로 마무리를
/// 유도하므로 UI가 개입하면 두 번 재촉하는 셈이 된다 (§7 결정 1).
abstract final class SessionClock {
  /// 하드컷 몇 초 전부터 조용한 표시를 띄우는지.
  ///
  /// 남은 시간을 계속 보여주면 털어놓는 데 압박이 되므로 **마지막 1분만**
  /// 알린다 (§7 결정 1).
  static const nearEndLead = Duration(seconds: 60);

  /// 하드컷까지 남은 시간.
  static Duration hardCutAfter(int hardCutSec) =>
      Duration(seconds: hardCutSec < 0 ? 0 : hardCutSec);

  /// "잠시 뒤 마무리됩니다"를 띄울 시점.
  ///
  /// 남은 시간이 1분 이하로 들어온 경우(이어하기)에는 **즉시** 띄운다 —
  /// 60을 빼서 음수가 되면 타이머가 안 걸려 표시가 통째로 빠진다.
  static Duration nearEndAfter(int hardCutSec) {
    final left = hardCutAfter(hardCutSec) - nearEndLead;
    return left.isNegative ? Duration.zero : left;
  }

  /// 하드컷 시점에 서버로 보내는 사유 (계약 §2-5).
  static const reasonHardCut = 'hard_cut';

  /// 사용자가 "대화 마치기"를 눌렀을 때.
  static const reasonUserEnd = 'user_end';
}
