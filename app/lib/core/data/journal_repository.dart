import '../models/auth_models.dart';
import '../models/live_models.dart';
import '../models/observation_models.dart';
import '../models/paged.dart';
import '../models/record_models.dart';
import '../models/session_models.dart';
import '../models/trend_models.dart';

/// 화면이 데이터를 얻는 **유일한 경로** (계약서 §2).
///
/// 화면은 `Sample`도 `ApiClient`도 직접 보지 않는다. 구현이 둘이라 — 실제
/// API와 샘플 — 화면 코드를 고치지 않고 갈아끼울 수 있다.
///
abstract interface class JournalRepository {
  /// 로그인 (§2-1, v1.6). **인가 코드를 넘긴다** — 웹에서는 앱이 액세스
  /// 토큰을 받을 수 없다. `redirectUri`는 인가 때 쓴 값과 **정확히 같아야**
  /// 하고 서버가 등록 목록과 대조한다.
  Future<AuthResult> authKakao({
    required String kakaoAuthCode,
    required String redirectUri,
  });

  Future<Me> me();

  /// S03 발견 목록. §1-4 페이징.
  ///
  /// **`page`를 nullable로 둔 이유가 있다.** 인터페이스 쪽 optional 파라미터에
  /// 기본값을 두고 구현에서만 채우면, 호출부가 인터페이스 타입일 때 dart2js가
  /// `null`을 넘겨 `NoSuchMethodError`로 죽는다 — **VM 테스트는 통과하고 웹
  /// 릴리스에서만 터진다.** 기본값은 구현이 `?? const PageQuery()`로 채운다.
  Future<Paged<Observation>> observations({PageQuery? page});

  /// S03-1 관찰 근거.
  Future<ObservationEvidence> evidence(String observationId);

  /// F7-08 "맞아요 / 아니에요".
  Future<FeedbackResult> sendFeedback(String observationId, {required bool agree});

  /// S04 추세. `tagGaps`·`userAvgGap`이 같은 응답에 실려 온다 (v1.4 §2-8).
  Future<Trend> trend(String range);

  /// S05 기록 목록. `page`가 nullable인 이유는 위와 같다.
  Future<Paged<SessionSummary>> sessions({PageQuery? page});

  /// S05-1 대화 상세.
  Future<SessionDetail> session(String sessionId);

  Future<SessionDeleteResult> deleteSession(String sessionId);

  Future<SessionStart> startSession();
  Future<SessionResume> resumeSession(String sessionId);
  /// 세션 종료 (§2-5). `endReason`은 `user_end` | `soft_wrap` | `hard_cut`
  /// 중 하나다 — **앱은 `timeout`·`resumed`를 보내지 않는다.**
  Future<SessionEnd> endSession(String sessionId, {required String endReason});

  /// S02 폴링 — 위기 신호와 데모용 턴 (§2-13).
  Future<LiveSignal> live(String sessionId);

  /// 탈퇴. `kakaoAuthCode`가 있으면 백엔드가 연결 해제까지 한다 (v1.6 §2-3).
  Future<void> deleteAccount({String? kakaoAuthCode, String? redirectUri});
}
