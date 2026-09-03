import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/token_storage.dart';

/// 진입 자격 — 라우터 가드가 보는 상태.
enum GateStatus {
  /// 아직 저장소를 읽지 못했다. 리다이렉트를 보류한다.
  unknown,

  /// 온보딩 고지에 동의하지 않았다 → S00.
  needsOnboarding,

  /// 동의는 했지만 로그인되지 않았다 → S00(로그인).
  needsLogin,

  /// 통과.
  ready,
}

/// 온보딩 동의 여부와 JWT 보유를 합친 진입 자격.
///
/// **F1-05: 동의 없이 대화 화면으로 진입할 수 없다.** 웹은 주소창에 URL을 치면
/// 화면으로 바로 들어가므로 이 가드가 없으면 수용 기준이 깨진다.
class AppSession extends ChangeNotifier {
  AppSession(this._tokens) {
    _load();
  }

  final TokenStorage _tokens;

  GateStatus _status = GateStatus.unknown;
  GateStatus get status => _status;

  bool get isReady => _status == GateStatus.ready;

  Future<void> _load() async {
    final seen = await _tokens.hasSeenOnboarding();
    final jwt = await _tokens.readJwt();
    _set(resolve(seenOnboarding: seen, jwt: jwt));
  }

  /// 저장소 상태 → 진입 자격. 순수 함수라 테스트에서 직접 쓴다.
  @visibleForTesting
  static GateStatus resolve({
    required bool seenOnboarding,
    required String? jwt,
  }) {
    if (!seenOnboarding) return GateStatus.needsOnboarding;
    if (jwt == null || jwt.isEmpty) return GateStatus.needsLogin;
    return GateStatus.ready;
  }

  /// 온보딩 고지를 본 뒤 카카오 로그인이 끝났을 때.
  Future<void> completeLogin(String jwt) async {
    await _tokens.markOnboardingSeen();
    await _tokens.writeJwt(jwt);
    _set(GateStatus.ready);
  }

  /// 고지만 확인했을 때(로그인 전).
  Future<void> acceptOnboarding() async {
    await _tokens.markOnboardingSeen();
    _set(GateStatus.needsLogin);
  }

  /// 로그아웃 — 기기의 토큰만 지운다. 동의 기록은 남긴다 (F1-03).
  Future<void> signOut() async {
    await _tokens.clearAll();
    _set(GateStatus.needsLogin);
  }

  /// 탈퇴 후 — 동의 기록까지 지워 처음 상태로 돌린다 (F1-04).
  Future<void> reset() async {
    await _tokens.clearAll();
    _set(GateStatus.needsOnboarding);
  }

  void _set(GateStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }
}

final appSessionProvider = ChangeNotifierProvider<AppSession>((ref) {
  return AppSession(ref.watch(tokenStorageProvider));
});
