/// 계약서 §1-2 오류 응답.
///
/// ```json
/// { "error": { "code": "SESSION_NOT_FOUND", "message": "...", "traceId": "..." } }
/// ```
///
/// **분기는 `code`로 하고 `message`로 하지 않는다** (§1-2). `message`는
/// 사용자에게 그대로 보여도 되는 한국어 문장이다.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.traceId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? traceId;

  /// 서버가 규약 밖 응답을 준 경우 — 문구는 앱이 만든다.
  factory ApiException.unexpected([int? statusCode]) => ApiException(
        code: ApiErrorCode.internalError,
        message: '문제가 생겼습니다. 잠시 후 다시 시도해 주세요.',
        statusCode: statusCode,
      );

  factory ApiException.network() => const ApiException(
        code: ApiErrorCode.networkUnavailable,
        message: '연결이 끊어졌습니다. 다시 연결해 볼까요?',
      );

  bool get isTokenExpired => code == ApiErrorCode.tokenExpired;

  @override
  String toString() => 'ApiException($code, status=$statusCode)';
}

/// 계약서 §1-2의 code 목록. 앱이 분기하는 값만 상수로 둔다.
abstract final class ApiErrorCode {
  static const validationError = 'VALIDATION_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const kakaoVerifyFailed = 'KAKAO_VERIFY_FAILED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const sessionNotFound = 'SESSION_NOT_FOUND';
  static const observationNotFound = 'OBSERVATION_NOT_FOUND';

  /// 이어하기 창(30분) 경과 또는 잔여 시간 없음 → 앱은 새 세션을 시작한다.
  static const sessionNotResumable = 'SESSION_NOT_RESUMABLE';

  /// Hume 액세스 토큰 발급 실패 → 대화 시작을 **차단**하고 안내한다 (F2-01).
  static const humeTokenIssueFailed = 'HUME_TOKEN_ISSUE_FAILED';

  static const internalError = 'INTERNAL_ERROR';

  /// 서버가 준 code가 아니라 앱이 네트워크 실패에 붙이는 값.
  static const networkUnavailable = 'NETWORK_UNAVAILABLE';
}
