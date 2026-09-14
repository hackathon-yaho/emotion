import 'package:flutter_test/flutter_test.dart';

import 'package:voice_journal/core/router/routes.dart';

/// **요약 라우트를 대화 밑에 두지 않는다.**
///
/// go_router는 자식 라우트로 갈 때 **부모 페이지를 함께 만든다.** 요약이
/// `/conversation/summary`였을 때, 대화를 끝낼 때마다 대화 화면이 새로
/// 만들어져 `initState` → `_open()` → **세션이 하나 더 열렸다.** 그 빈 세션은
/// 홈에 「중단된 대화」로 남고, 요약 화면에 머무는 동안 **숨은 화면의 마이크가
/// Hume에 연결돼 있었다**(백엔드 실측 105초·122초).
///
/// 이 한 줄이 그 구조를 잠근다 — 다시 중첩되면 여기서 깨진다.
void main() {
  test('요약은 대화의 자식 라우트가 아니다 (2026-09-15 회귀)', () {
    expect(
      Routes.summary.startsWith('${Routes.conversation}/'),
      isFalse,
      reason: '자식으로 두면 대화 화면이 다시 만들어져 세션이 하나 더 열린다',
    );
  });
}
