import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경변수. **앱에 하드코딩하지 않는다** (계약서 §1-1).
abstract final class Env {
  static Future<void> load() => dotenv.load();

  /// 백엔드 배포 도메인.
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:8080';

  /// 카카오 JavaScript 앱 키 (웹 로그인).
  static String? get kakaoJsKey {
    final v = dotenv.maybeGet('KAKAO_JS_KEY');
    return (v == null || v.isEmpty) ? null : v;
  }
}
