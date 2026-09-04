import '../models/observation_models.dart';
import '../models/record_models.dart';
import '../models/trend_models.dart';
import '../../shared/widgets/tag_gap_bars.dart';

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
  );

  static const userAvgGap = 0.72;

  static const tagGaps = <TagGap>[
    TagGap(tag: '회의', occurrences: 7, tagAvgGap: 1.31),
    TagGap(tag: '주말', occurrences: 4, tagAvgGap: 1.16),
    TagGap(tag: '야근', occurrences: 4, tagAvgGap: 0.98),
    TagGap(tag: '팀장', occurrences: 3, tagAvgGap: 0.88),
    TagGap(tag: '가족', occurrences: 4, tagAvgGap: 0.65),
  ];
}
