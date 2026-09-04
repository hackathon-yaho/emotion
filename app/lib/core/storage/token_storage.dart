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
  static const _themeKey = 'theme';
  static const _demoKey = 'demo';

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

  /// 화면 설정 — **비밀이 아니지만** 저장소를 하나로 유지한다. 값 하나
  /// 때문에 의존성을 더 넣는 것보다 낫다.
  ///
  /// `system` | `dark` | `light`. 없으면 시스템 설정을 따른다
  /// (design-system §4).
  Future<String?> readThemeMode() => _storage.read(key: _themeKey);
  Future<void> writeThemeMode(String mode) =>
      _storage.write(key: _themeKey, value: mode);

  /// F11-01 데모 모드 — **시연용 로컬 설정**이다. 계약에 변경 엔드포인트가
  /// 없어 서버로 올리지 않는다.
  Future<bool> readDemoMode() async =>
      (await _storage.read(key: _demoKey)) == 'true';
  Future<void> writeDemoMode(bool on) =>
      _storage.write(key: _demoKey, value: on.toString());

  /// 로그아웃 — 기기의 토큰만 지운다. 서버 데이터는 남는다 (F1-03).
  Future<void> clearAll() async {
    await clearJwt();
  }
}
