import '../models/auth_models.dart';
import '../models/live_models.dart';
import '../models/observation_models.dart';
import '../models/record_models.dart';
import '../models/session_models.dart';
import '../models/trend_models.dart';

/// 화면을 그려 보기 위한 **샘플 데이터**.
///
/// **발표 근거로 쓰지 않는다** — PRD §12: "샘플 데이터는 개발·테스트 전용,
/// 발표 근거는 실사용 로그만". 시뮬레이션 그래프는 "직접 만드신 거죠?" 한
/// 마디에 발견 기능 전체를 연출로 격하시킨다.
///
/// API가 붙으면 이 파일을 참조하는 화면들이 프로바이더로 바뀐다.
abstract final class Sample {
  static final observations = <Observation>[
    Observation(
      observationId: 'obs_014',
      createdAt: DateTime(2026, 9, 14, 9),
      sentence: '회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.',
      evidence: const Evidence(
        tag: '회의',
        occurrences: 7,
        tagAvgGap: 1.31,
        userAvgGap: 0.72,
        ratio: 1.82,
      ),
    ),
    Observation(
      observationId: 'obs_012',
      createdAt: DateTime(2026, 9, 11, 9),
      sentence: '주말 이야기를 할 때는 말이 조금 빨라지시네요.',
      evidence: const Evidence(
        tag: '주말',
        occurrences: 4,
        tagAvgGap: 1.16,
        userAvgGap: 0.72,
        ratio: 1.61,
      ),
    ),
  ];

  static final evidenceDetail = ObservationEvidence(
    observationId: 'obs_014',
    sentence: '회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.',
    evidence: const Evidence(
      tag: '회의',
      occurrences: 7,
      tagAvgGap: 1.31,
      userAvgGap: 0.72,
      ratio: 1.82,
    ),
    turns: [
      EvidenceTurn(
        turnId: 'turn_0031',
        sessionId: 'sess_1',
        occurredAt: DateTime(2026, 9, 12, 13, 20),
        transcript: '오늘 회의가 세 개나 있었는데 다 괜찮았어요',
        textValence: 0.62,
        voiceValence: -0.58,
        gap: 1.20,
      ),
      EvidenceTurn(
        turnId: 'turn_0028',
        sessionId: 'sess_2',
        occurredAt: DateTime(2026, 9, 11, 22, 4),
        transcript: '회의 끝나고 나면 왜 이렇게 진이 빠지는지',
        textValence: 0.34,
        voiceValence: -1.08,
        gap: 1.42,
      ),
      EvidenceTurn(
        turnId: 'turn_0019',
        sessionId: 'sess_3',
        occurredAt: DateTime(2026, 9, 8, 21, 38),
        transcript: '내일도 회의라서 좀 그렇네요',
        textValence: 0.48,
        voiceValence: -0.70,
        gap: 1.18,
      ),
    ],
  );

  static final sessions = <SessionSummary>[
    SessionSummary(
      sessionId: 'sess_1',
      startedAt: DateTime(2026, 9, 14, 21, 30),
      durationSec: 214,
      turnCount: 12,
      summary: '회의가 많았던 하루에 대해 이야기했습니다.',
      gapAvg: 0.94,
      tags: const ['회의', '야근'],
    ),
    SessionSummary(
      sessionId: 'sess_2',
      startedAt: DateTime(2026, 9, 13, 22, 4),
      durationSec: 178,
      turnCount: 9,
      summary: '늦게까지 남아 일한 이야기를 했습니다.',
      gapAvg: 0.71,
      tags: const ['야근', '팀장'],
    ),
    SessionSummary(
      sessionId: 'sess_3',
      startedAt: DateTime(2026, 9, 12, 20, 12),
      durationSec: 242,
      turnCount: 14,
      summary: '가족과 통화한 이야기를 했습니다.',
      gapAvg: 0.38,
      tags: const ['가족', '엄마'],
    ),
    SessionSummary(
      sessionId: 'sess_4',
      startedAt: DateTime(2026, 9, 11, 23, 1),
      durationSec: 191,
      turnCount: 11,
      summary: '회의 준비가 버거웠던 이야기를 했습니다.',
      gapAvg: 1.02,
      tags: const ['회의'],
    ),
  ];

  static final sessionDetail = SessionDetail(
    sessionId: 'sess_1',
    startedAt: DateTime(2026, 9, 14, 21, 30),
    endedAt: DateTime(2026, 9, 14, 21, 33, 34),
    durationSec: 214,
    endReason: 'user_end',
    thresholdMode: 'fixed',
    summary: '회의가 많았던 하루에 대해 이야기했습니다.',
    turns: [
      Turn(
        turnId: 't1',
        turnIndex: 3,
        occurredAt: DateTime(2026, 9, 14, 21, 31, 2),
        role: 'user',
        transcript: '오늘 완전 괜찮았어요',
        textValence: 0.70,
        voiceValence: -0.62,
        gap: 1.32,
        gapTriggered: true,
        tags: const ['회의'],
      ),
      Turn(
        turnId: 't2',
        turnIndex: 4,
        occurredAt: DateTime(2026, 9, 14, 21, 31, 6),
        role: 'assistant',
        transcript: '괜찮다고 하시는데 목소리는 좀 다르네요. 무슨 일 있으셨어요?',
        textValence: null,
        voiceValence: null,
        gap: null,
        gapTriggered: false,
        tags: const [],
      ),
      Turn(
        turnId: 't3',
        turnIndex: 5,
        occurredAt: DateTime(2026, 9, 14, 21, 31, 40),
        role: 'user',
        transcript: '회의가 세 개나 있었는데, 뭐 늘 그렇죠',
        textValence: 0.31,
        voiceValence: -0.44,
        gap: 0.75,
        gapTriggered: false,
        tags: const ['회의'],
      ),
    ],
  );

  /// 기록이 없는 날(9/4 · 9/9 · 9/10)은 **배열에서 아예 빠져 있다** —
  /// 계약서 §1-3대로 0으로 채우지 않는다. 그래서 그래프가 선을 끊는다.
  static final trend = Trend(
    range: TrendRange.d30,
    timezone: 'Asia/Seoul',
    points: const [
      // 범위가 30일이면 표본도 30일이어야 밀도를 실제로 확인할 수 있다.
      // 8/16~8/31 구간은 하루당 폭이 임계(14px) 아래로 떨어지는 상황을
      // 만들기 위해 있다 — 8/22·8/27은 기록 없는 날(선이 끊긴다).
      TrendPoint(date: '2026-08-16', textValence: 0.22, voiceValence: 0.14, gap: 0.08, sessionCount: 1),
      TrendPoint(date: '2026-08-17', textValence: 0.30, voiceValence: 0.19, gap: 0.11, sessionCount: 1),
      TrendPoint(date: '2026-08-18', textValence: 0.18, voiceValence: -0.02, gap: 0.20, sessionCount: 1),
      TrendPoint(date: '2026-08-19', textValence: 0.26, voiceValence: 0.08, gap: 0.18, sessionCount: 1),
      TrendPoint(date: '2026-08-20', textValence: 0.34, voiceValence: 0.12, gap: 0.22, sessionCount: 2),
      TrendPoint(date: '2026-08-21', textValence: 0.28, voiceValence: -0.06, gap: 0.34, sessionCount: 1),
      TrendPoint(date: '2026-08-23', textValence: 0.40, voiceValence: 0.05, gap: 0.35, sessionCount: 1),
      TrendPoint(date: '2026-08-24', textValence: 0.33, voiceValence: -0.10, gap: 0.43, sessionCount: 1),
      TrendPoint(date: '2026-08-25', textValence: 0.21, voiceValence: -0.14, gap: 0.35, sessionCount: 1),
      TrendPoint(date: '2026-08-26', textValence: 0.29, voiceValence: 0.02, gap: 0.27, sessionCount: 1),
      TrendPoint(date: '2026-08-28', textValence: 0.37, voiceValence: 0.16, gap: 0.21, sessionCount: 1),
      TrendPoint(date: '2026-08-29', textValence: 0.24, voiceValence: 0.09, gap: 0.15, sessionCount: 1),
      TrendPoint(date: '2026-08-30', textValence: 0.31, voiceValence: 0.21, gap: 0.10, sessionCount: 1),
      TrendPoint(date: '2026-08-31', textValence: 0.27, voiceValence: 0.17, gap: 0.10, sessionCount: 2),
      TrendPoint(date: '2026-09-01', textValence: 0.35, voiceValence: 0.20, gap: 0.15, sessionCount: 1),
      TrendPoint(date: '2026-09-02', textValence: 0.42, voiceValence: 0.10, gap: 0.32, sessionCount: 1),
      TrendPoint(date: '2026-09-03', textValence: 0.30, voiceValence: -0.05, gap: 0.35, sessionCount: 2),
      TrendPoint(date: '2026-09-05', textValence: 0.55, voiceValence: -0.20, gap: 0.75, sessionCount: 1),
      TrendPoint(date: '2026-09-06', textValence: 0.61, voiceValence: -0.42, gap: 1.03, sessionCount: 1),
      TrendPoint(date: '2026-09-07', textValence: 0.58, voiceValence: -0.50, gap: 1.08, sessionCount: 1),
      TrendPoint(date: '2026-09-08', textValence: 0.44, voiceValence: -0.30, gap: 0.74, sessionCount: 1),
      TrendPoint(date: '2026-09-11', textValence: 0.20, voiceValence: 0.11, gap: 0.09, sessionCount: 1),
      TrendPoint(date: '2026-09-12', textValence: 0.15, voiceValence: 0.05, gap: 0.10, sessionCount: 1),
      TrendPoint(date: '2026-09-13', textValence: -0.10, voiceValence: -0.22, gap: 0.12, sessionCount: 1),
      TrendPoint(date: '2026-09-14', textValence: 0.25, voiceValence: 0.18, gap: 0.07, sessionCount: 2),
    ],
    highlights: const [
      TrendHighlight(from: '2026-09-06', to: '2026-09-07', reason: 'gap_exceeded'),
    ],
    // v1.4 §2-8 — 같은 응답에 실려 온다. 별도 호출이 아니다.
    userAvgGap: 0.72,
    tagGaps: const [
      TagGap(tag: '회의', occurrences: 7, tagAvgGap: 1.31),
      TagGap(tag: '주말', occurrences: 4, tagAvgGap: 1.16),
      TagGap(tag: '야근', occurrences: 4, tagAvgGap: 0.98),
      TagGap(tag: '팀장', occurrences: 3, tagAvgGap: 0.88),
      TagGap(tag: '가족', occurrences: 4, tagAvgGap: 0.65),
    ],
  );

  /// `POST /api/auth/kakao` — 샘플 모드에서 로그인 화면을 통과시키기 위한 값.
  ///
  /// **JWT가 가짜다.** 샘플 모드는 백엔드를 타지 않으므로 이 토큰으로 실제
  /// 호출이 나갈 일이 없다.
  static final authResult = AuthResult(
    jwt: 'sample-not-a-real-jwt',
    expiresAt: DateTime.now().add(const Duration(days: 7)),
    profileId: 'prof_sample',
    isNewUser: false,
  );

  /// `GET /api/me` — 신규 계정이 아니라 **며칠 써 본 계정**이다. 샘플 화면이
  /// 빈 상태로만 보이면 확인할 게 없다.
  static final me = Me(
    profileId: 'prof_sample',
    joinedAt: DateTime.parse('2026-08-16T09:00:00Z'),
    sessionCount: 12,
    thresholdMode: 'personal',
    demoMode: false,
    openSession: null,
  );

  /// `POST /api/session/start` — **Hume 토큰이 가짜다.**
  ///
  /// 샘플 모드의 존재 이유가 여기다. 이 값으로는 EVI에 붙지 못하므로
  /// 실수로 실제 통화가 열려 과금되는 일이 없다. 앱은 샘플 모드에서 EVI
  /// 연결을 아예 시도하지 않는다.
  static final sessionStart = SessionStart(
    sessionId: '00000000-0000-4000-8000-000000000001',
    humeAccessToken: 'sample-not-a-real-token',
    humeTokenExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
    thresholdMode: 'personal',
    gapThreshold: 0.90,
    softWrapSec: 300,
    hardCutSec: 420,
    demoMode: true,
    humeConfigId: 'sample-config',
    livePollIntervalSec: 2,
  );

  static final sessionResume = SessionResume(
    sessionId: '00000000-0000-4000-8000-000000000001',
    humeAccessToken: 'sample-not-a-real-token',
    resumedChatGroupId: 'sample-chat-group',
    remainingSec: 282,
    thresholdMode: 'personal',
    gapThreshold: 0.90,
    demoMode: true,
    humeConfigId: 'sample-config',
  );

  /// 데모 모드 패널에 실리는 턴. 갭이 임계를 넘은 턴이라 **되묻는 상태**를
  /// 확인할 수 있다 (FR-022).
  static LiveTurn liveTurn(int index) => LiveTurn(
        turnIndex: index,
        textValence: 0.70,
        voiceValence: -0.62,
        gap: 1.32,
        gapTriggered: true,
      );

  /// 기간별 추세. **7일은 30일에서 잘라 쓴다** — 표본을 따로 두면 두 화면이
  /// 서로 다른 이야기를 하게 된다.
  static Trend trendOf(String range) {
    if (range == TrendRange.d7) {
      final last7 = trend.points.length <= 7
          ? trend.points
          : trend.points.sublist(trend.points.length - 7);
      final from = last7.first.date;
      return Trend(
        range: range,
        timezone: trend.timezone,
        points: last7,
        // 7일 창 밖의 음영은 버린다 — 없는 구간을 그리면 안 된다.
        highlights: trend.highlights
            .where((h) => h.from.compareTo(from) >= 0)
            .toList(growable: false),
        userAvgGap: trend.userAvgGap,
        tagGaps: trend.tagGaps,
      );
    }
    return trend;
  }
}
