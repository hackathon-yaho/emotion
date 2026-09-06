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
  static const _unlinkKey = 'pending_unlink';

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

  /// 탈퇴하러 카카오 인가에 다녀오는 중인지 (F10-03).
  ///
  /// **웹은 인가 페이지로 나갔다가 앱이 새로 뜬다.** 돌아온 코드가 로그인용인지
  /// 탈퇴용인지 주소만 봐서는 구별할 수 없어, 나가기 전에 여기에 적어 둔다.
  Future<bool> readPendingUnlink() async =>
      (await _storage.read(key: _unlinkKey)) == 'true';
  Future<void> markPendingUnlink() =>
      _storage.write(key: _unlinkKey, value: 'true');
  Future<void> clearPendingUnlink() => _storage.delete(key: _unlinkKey);

  /// 로그아웃 — 기기의 토큰만 지운다. 서버 데이터는 남는다 (F1-03).
  ///
  /// **탈퇴 표시도 함께 지운다.** 남겨 두면 다음 로그인 복귀에서 그 코드를
  /// 탈퇴로 오해한다.
  Future<void> clearAll() async {
    await clearJwt();
    await clearPendingUnlink();
  }
}
