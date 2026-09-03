import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경변수. **앱에 하드코딩하지 않는다** (계약서 §1-1).
abstract final class Env {
  static Future<void> load() => dotenv.load();

  /// 백엔드 배포 도메인.
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:8080';

  /// Hume EVI Config ID.
  ///
  /// **임시 경로다.** 계약에 필드가 없어서 로컬 `.env`로 쓰고 있으며,
  /// 백엔드가 `POST /api/session/start` 응답에 `humeConfigId`를 넣으면
  /// 이 값을 지운다 — `docs/request/backend/hume-config-id.md` (⏳).
  /// **저장소에 상수로 커밋하지 않는다.**
  static String? get humeConfigIdFallback {
    final v = dotenv.maybeGet('HUME_CONFIG_ID');
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 카카오 JavaScript 앱 키 (웹 로그인).
  static String? get kakaoJsKey {
    final v = dotenv.maybeGet('KAKAO_JS_KEY');
    return (v == null || v.isEmpty) ? null : v;
  }
}
