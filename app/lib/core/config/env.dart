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
///   --dart-define=KAKAO_REST_KEY=...
/// ```
abstract final class Env {
  /// 백엔드 배포 도메인.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// 카카오 JavaScript 앱 키 (웹 로그인). 공개되는 키이며 도메인 등록으로
  /// 보호된다. 비어 있으면 로그인 버튼이 안내만 띄운다.
  /// 카카오 **REST API 키** — 인가 URL의 `client_id`.
  ///
  /// JS 키가 아니다 (`response/backend/kakao-rest-key-switch.md`). 웹에서는
  /// SDK 로그인이 전부 `notSupported`라 SDK를 쓰지 않고, 인가 URL을 직접
  /// 만든다 — 그 URL의 `client_id`와 서버의 토큰 교환 `client_id`가 **같아야**
  /// 하고, 교환은 REST 키 + 시크릿으로 한다.
  ///
  /// **번들에 들어가는 것이 정상이다.** 인가 URL에 실리는 값이라 어차피
  /// 주소창에 보인다. 보호는 **클라이언트 시크릿(서버에만)** 과 **Redirect URI
  /// 화이트리스트**가 한다 — Hume 키를 앱에 두지 않는 것(FR-013)과는 성격이
  /// 다른 값이다.
  static const _kakaoRestKey = String.fromEnvironment('KAKAO_REST_KEY');

  static String? get kakaoRestKey =>
      _kakaoRestKey.isEmpty ? null : _kakaoRestKey;

  /// Hume Config ID는 여기 없다 — 계약 v1.3부터
  /// `POST /api/session/start` 응답의 `humeConfigId`로 온다 (§2-4).
  /// 백엔드가 기동 시 fail-fast로 검증하므로 앱은 폴백을 두지 않는다.
  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  /// 샘플 모드로 빌드할지 — `--dart-define=SAMPLE_DATA=true`.
  ///
  /// **실제 Hume API를 켜 두고 테스트할 수 없어서** 있는 스위치다. 켜면
  /// 백엔드·Hume을 타지 않고 화면과 흐름만 확인한다. 주소에 `?sample=1`을
  /// 붙여도 같다 (`dataModeProvider`).
  static const sampleData = bool.fromEnvironment('SAMPLE_DATA');

  /// EVI 소켓 주소를 갈아끼운다 — **개발·검증 전용**.
  ///
  /// 마이크 왕복을 확인하려면 Hume 토큰이 필요한데 그 토큰은 로그인 →
  /// `session/start`를 거쳐야만 나온다. 이 값을 주면 **가짜 EVI 서버**에
  /// 붙어 마이크 캡처·PCM 프레이밍·전송·재생까지를 Hume 없이 확인할 수 있다.
  ///
  /// **비어 있으면 항상 `wss://api.hume.ai`다.** 배포 빌드에는 값이 없다.
  static const _eviWsUrl = String.fromEnvironment('EVI_WS_URL');

  static String? get eviWsUrl => _eviWsUrl.isEmpty ? null : _eviWsUrl;

  /// 실패 원인을 화면에 그대로 띄운다 — **개발·통합 전용, 기본 꺼짐.**
  ///
  /// F2-04는 원인을 사용자 말로 옮기라고 하고 상태 코드·`traceId`를 화면에
  /// 쓰지 않는다(§7-1). 그런데 통합 중에는 그 규칙이 **원인을 통째로 숨겨서**
  /// 2026-09-06에 한참을 헤맸다(모델 파싱 실패가 "지금은 대화를 시작할 수
  /// 없습니다" 한 줄로만 보였다). 그때만 켠다.
  static const showErrorDetail = bool.fromEnvironment('SHOW_ERROR_DETAIL');
  static bool get hasEviOverride => eviWsUrl != null;
}
