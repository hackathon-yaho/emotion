/// 환경변수. **앱에 하드코딩하지 않는다** (계약서 §1-1).
///
/// `--dart-define`으로 주입한다. `.env` 파일을 애셋으로 등록하지 않는 이유는
/// **클론한 사람이 파일을 만들지 않으면 빌드가 실패**하기 때문이다 —
/// `.env`는 `.gitignore` 대상이라 새로 클론한 팀원에게는 항상 없다.
/// 기본값이 있으므로 아무 설정 없이도 빌드·실행된다.
///
/// ```bash
/// flutter run -d chrome \
///   --dart-define=API_BASE_URL=http://localhost:8080 \
///   --dart-define=KAKAO_JS_KEY=...
/// ```
abstract final class Env {
  /// 백엔드 배포 도메인.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// 카카오 JavaScript 앱 키 (웹 로그인). 공개되는 키이며 도메인 등록으로
  /// 보호된다. 비어 있으면 로그인 버튼이 안내만 띄운다.
  static const _kakaoJsKey = String.fromEnvironment('KAKAO_JS_KEY');

  static String? get kakaoJsKey => _kakaoJsKey.isEmpty ? null : _kakaoJsKey;

  /// Hume Config ID는 여기 없다 — 계약 v1.3부터
  /// `POST /api/session/start` 응답의 `humeConfigId`로 온다 (§2-4).
  /// 백엔드가 기동 시 fail-fast로 검증하므로 앱은 폴백을 두지 않는다.
  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
