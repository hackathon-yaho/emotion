import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT 보관. 만료 7일 (계약서 §1-1).
///
/// 감정 데이터를 다루는 앱이라 평문 저장을 쓰지 않는다. 웹에서는 브라우저
/// 저장소가 비어 있을 수 있으므로 항상 null을 처리한다.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _jwtKey = 'jwt';
  static const _onboardedKey = 'onboarded';

  Future<String?> readJwt() => _storage.read(key: _jwtKey);
  Future<void> writeJwt(String jwt) => _storage.write(key: _jwtKey, value: jwt);
  Future<void> clearJwt() => _storage.delete(key: _jwtKey);

  /// 온보딩 고지를 본 적이 있는지.
  ///
  /// **로컬 플래그가 우선이고 `isNewUser`는 보조다** (design-system §7-2).
  /// F1-05는 고지를 **로그인 전**에 띄우라고 하는데 `isNewUser`는 로그인
  /// 응답으로 오므로 그것만으로는 성립하지 않는다. 저장소가 비면 다시
  /// 노출되는 쪽이 안전한 방향이다.
  Future<bool> hasSeenOnboarding() async =>
      (await _storage.read(key: _onboardedKey)) == 'true';

  Future<void> markOnboardingSeen() =>
      _storage.write(key: _onboardedKey, value: 'true');

  /// 로그아웃 — 기기의 토큰만 지운다. 서버 데이터는 남는다 (F1-03).
  Future<void> clearAll() async {
    await clearJwt();
  }
}
