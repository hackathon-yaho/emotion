/// 계약서 §2-1 `POST /api/auth/kakao`. 인증 불필요.
class AuthResult {
  const AuthResult({
    required this.jwt,
    required this.expiresAt,
    required this.profileId,
    required this.isNewUser,
  });

  final String jwt;

  /// JWT 만료 — 7일 (계약서 §1-1).
  final DateTime expiresAt;

  /// **재로그인 시 동일한 `profileId`가 와야 한다** (spec TC-01).
  final String profileId;

  /// 온보딩 고지를 띄울지 판단하는 **보조** 신호다.
  ///
  /// F1-05는 고지를 **로그인 전**에 띄우라고 하는데 이 값은 로그인 응답으로
  /// 오므로 이것만으로는 성립하지 않는다. 로컬 플래그가 우선이다
  /// (design-system §7-2, [TokenStorage.hasSeenOnboarding]).
  final bool isNewUser;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        jwt: j['jwt'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        profileId: j['profileId'] as String,
        isNewUser: j['isNewUser'] as bool? ?? false,
      );
}

/// 계약서 §2-7-1 `POST /api/observations/{id}/feedback` 응답.
class FeedbackResult {
  const FeedbackResult({required this.observationId, required this.feedback});

  final String observationId;

  /// `agree` | `disagree`.
  final String feedback;

  factory FeedbackResult.fromJson(Map<String, dynamic> j) => FeedbackResult(
        observationId: j['observationId'] as String,
        feedback: j['feedback'] as String,
      );
}

/// 계약서 §2-12 `GET /api/health`. 인증 불필요.
class Health {
  const Health({
    required this.status,
    required this.db,
    required this.timestamp,
  });

  final String status;
  final String db;
  final DateTime timestamp;

  bool get isOk => status == 'ok' && db == 'ok';

  factory Health.fromJson(Map<String, dynamic> j) => Health(
        status: j['status'] as String,
        db: j['db'] as String? ?? 'unknown',
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
