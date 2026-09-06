import 'session_models.dart';

/// 대화 대기열 (계약 v1.9 §2-14).
///
/// **Hume은 대기를 지원하지 않는다** — 동시 접속 상한(Free 1 · Starter 5)을
/// 넘긴 연결은 `E0700`으로 즉시 거절된다. 순번·대기 시간은 전부 우리 서버가
/// 만든 것이다.
///
/// **서버 기본은 꺼짐이다.** 꺼진 상태에서는 §2-4가 202를 내지 않는다.
class QueueTicket {
  const QueueTicket({
    required this.ticketId,
    required this.position,
    required this.pollIntervalSec,
    this.session,
  });

  final String ticketId;

  /// **1부터 센다** — 내 앞에 몇 명이 아니라 **내가 몇 번째**다.
  /// `0`은 "입장했다"는 뜻이고 이때만 [session]이 채워진다.
  final int position;

  /// 폴링 간격(초). **앱에 상수로 박지 않는다** — 서버가 준 값을 쓴다.
  final int pollIntervalSec;

  /// `position > 0`이면 항상 null. 자리를 미리 잡아 두지 않기 때문이다.
  final SessionStart? session;

  bool get isReady => position == 0 && session != null;

  factory QueueTicket.fromJson(Map<String, dynamic> j) => QueueTicket(
        ticketId: j['ticketId'] as String,
        position: j['position'] as int? ?? 0,
        pollIntervalSec: j['pollIntervalSec'] as int? ?? 2,
        session: j['session'] == null
            ? null
            : SessionStart.fromJson(j['session'] as Map<String, dynamic>),
      );
}

/// `POST /api/session/start`의 두 결과 (§2-4).
///
/// **200이면 세션, 202면 대기 티켓이다.** 상태 코드로 가른다 — 본문 모양으로
/// 짐작하면 모양이 겹치는 날 조용히 틀린다.
sealed class SessionStartResult {
  const SessionStartResult();
}

class SessionOpened extends SessionStartResult {
  const SessionOpened(this.session);
  final SessionStart session;
}

class SessionQueued extends SessionStartResult {
  const SessionQueued(this.ticket);
  final QueueTicket ticket;
}
