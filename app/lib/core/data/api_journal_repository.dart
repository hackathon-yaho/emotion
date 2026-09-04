import '../models/auth_models.dart';
import '../models/live_models.dart';
import '../models/observation_models.dart';
import '../models/paged.dart';
import '../models/record_models.dart';
import '../models/session_models.dart';
import '../models/trend_models.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import 'journal_repository.dart';

/// 실제 백엔드 (계약서 §2).
class ApiJournalRepository implements JournalRepository {
  ApiJournalRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthResult> authKakao({
    required String kakaoAuthCode,
    required String redirectUri,
  }) =>
      _api.post(
        Endpoints.authKakao,
        // 인증 전이라 Authorization 헤더가 없다.
        authenticated: false,
        body: {'kakaoAuthCode': kakaoAuthCode, 'redirectUri': redirectUri},
        parse: AuthResult.fromJson,
      );

  @override
  Future<Me> me() => _api.get(Endpoints.me, parse: Me.fromJson);

  @override
  Future<Paged<Observation>> observations({PageQuery? page}) =>
      _api.get(
        Endpoints.observations,
        query: (page ?? const PageQuery()).toQuery(),
        parse: (j) => Paged.fromJson(
          j,
          key: 'observations',
          itemFromJson: Observation.fromJson,
        ),
      );

  @override
  Future<ObservationEvidence> evidence(String observationId) => _api.get(
        Endpoints.observationEvidence(observationId),
        parse: ObservationEvidence.fromJson,
      );

  @override
  Future<FeedbackResult> sendFeedback(
    String observationId, {
    required bool agree,
  }) =>
      _api.post(
        Endpoints.observationFeedback(observationId),
        body: {'agree': agree},
        parse: FeedbackResult.fromJson,
      );

  @override
  Future<Trend> trend(String range) => _api.get(
        Endpoints.trend,
        query: {'range': range},
        parse: Trend.fromJson,
      );

  @override
  Future<Paged<SessionSummary>> sessions({PageQuery? page}) =>
      _api.get(
        Endpoints.sessions,
        query: (page ?? const PageQuery()).toQuery(),
        parse: (j) => Paged.fromJson(
          j,
          key: 'sessions',
          itemFromJson: SessionSummary.fromJson,
        ),
      );

  @override
  Future<SessionDetail> session(String sessionId) => _api.get(
        Endpoints.session(sessionId),
        parse: SessionDetail.fromJson,
      );

  @override
  Future<SessionDeleteResult> deleteSession(String sessionId) => _api.delete(
        Endpoints.session(sessionId),
        parse: SessionDeleteResult.fromJson,
      );

  @override
  Future<SessionStart> startSession() => _api.post(
        Endpoints.sessionStart,
        parse: SessionStart.fromJson,
      );

  @override
  Future<SessionResume> resumeSession(String sessionId) => _api.post(
        Endpoints.sessionResume(sessionId),
        parse: SessionResume.fromJson,
      );

  @override
  Future<SessionEnd> endSession(String sessionId, {required String endReason}) =>
      _api.post(
        Endpoints.sessionEnd(sessionId),
        body: {'endReason': endReason},
        parse: SessionEnd.fromJson,
      );

  @override
  Future<LiveSignal> live(String sessionId) => _api.get(
        Endpoints.sessionLive(sessionId),
        parse: LiveSignal.fromJson,
      );

  @override
  Future<void> deleteAccount({String? kakaoAuthCode, String? redirectUri}) {
    // 본문은 선택이다 (v1.6 §2-3). 없으면 데이터만 지우고 **똑같이 204**를
    // 주며, 있으면 백엔드가 데이터를 지운 뒤 그 코드로 카카오 연결까지 끊는다.
    // 앱이 어드민 키를 갖지 않는 이유이기도 하다.
    final body = kakaoAuthCode == null
        ? null
        : {'kakaoAuthCode': kakaoAuthCode, 'redirectUri': redirectUri};
    return _api.deleteNoContent(Endpoints.account, body: body);
  }
}
