/// 계약서 §2 · §5 — 앱이 호출하는 경로.
///
/// 경로를 화면 코드에 흩지 않는다. 계약이 바뀌면 여기만 고친다.
abstract final class Endpoints {
  static const authKakao = '/api/auth/kakao';
  static const me = '/api/me';
  static const account = '/api/account';

  static const sessionStart = '/api/session/start';
  static String sessionEnd(String id) => '/api/session/$id/end';
  static String sessionResume(String id) => '/api/session/$id/resume';

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
