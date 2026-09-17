/// 계약서 §2 · §5 — 앱이 호출하는 경로.
///
/// 경로를 화면 코드에 흩지 않는다. 계약이 바뀌면 여기만 고친다.
abstract final class Endpoints {
  static const authKakao = '/api/auth/kakao';

  /// **심사용 로그인** — 카카오 없이 들어간다 (2026-09-18 요청).
  ///
  /// 심사위원이 카카오 계정 없이도 써 볼 수 있어야 한다. 백엔드가 이 경로를
  /// 만들고(`request/backend/dev-login.md`), 응답은 §2-1과 같은 모양이다 —
  /// 앱은 그 뒤를 카카오 로그인과 똑같이 처리한다.
  static const authDev = '/api/auth/dev';
  static const me = '/api/me';
  static const account = '/api/account';

  static const sessionStart = '/api/session/start';
  static String sessionEnd(String id) => '/api/session/$id/end';
  static String sessionResume(String id) => '/api/session/$id/resume';

  /// 대기열 순번 폴링 · 기다리기 그만두기 (계약 v1.9 §2-14).
  static String sessionQueue(String ticketId) =>
      '/api/session/queue/$ticketId';

  /// EVI가 준 `chat_group_id` 보관 (계약 v1.8 §2-5-2).
  static String sessionChatGroup(String id) => '/api/session/$id/chat-group';

  /// 대화 중 턴 신호 (계약 v1.3 §2-13). **S02에서만 폴링한다.**
  static String sessionLive(String id) => '/api/session/$id/live';

  static const observations = '/api/observations';
  static String observationEvidence(String id) =>
      '/api/observations/$id/evidence';
  static String observationFeedback(String id) =>
      '/api/observations/$id/feedback';

  static const trend = '/api/trend';
  static const sessions = '/api/sessions';
  static String session(String id) => '/api/sessions/$id';

  static const health = '/api/health';
}
