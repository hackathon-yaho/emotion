import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'data/api_journal_repository.dart';
import 'data/journal_repository.dart';
import 'data/sample_journal_repository.dart';
import 'models/live_models.dart';
import 'models/observation_models.dart';
import 'models/paged.dart';
import 'models/record_models.dart';
import 'models/session_models.dart';
import 'models/trend_models.dart';
import 'network/api_client.dart';
import 'voice/evi_service.dart';
import 'voice/mic.dart';
import 'voice/speaker.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokens: ref.watch(tokenStorageProvider));
});

/// 테마 모드. 기본은 시스템 설정을 따르고 S06에서 수동 전환한다
/// (design-system §4).
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// 대화가 진행 중인지.
///
/// JWT 만료(401)를 만나도 **대화 중이면 대화를 끊지 않는다** (F1-02). 인터셉터
/// 대신 이 신호를 보고 판단한다.
final inConversationProvider = StateProvider<bool>((_) => false);

// ---------------------------------------------------------------------------
// 데이터 출처
// ---------------------------------------------------------------------------

/// 화면이 무엇을 보고 그릴지.
///
/// **샘플 모드가 있는 이유는 Hume 과금이다.** EVI는 통화 시간만큼 돈이
/// 나가므로 화면·흐름을 확인할 때마다 실제 세션을 열 수 없다. 샘플 모드는
/// 백엔드도 Hume도 타지 않는다 — `SampleJournalRepository` 참조.
enum DataMode { live, sample }

/// 기본값은 빌드 인자 `SAMPLE_DATA`, 그리고 **주소의 `?sample=1`** 이다.
///
/// 배포된 URL에 `?sample=1`을 붙이면 팀원이 백엔드 없이도 전체 화면을 볼 수
/// 있다. 다시 빌드할 필요가 없어야 시연 리허설에서 쓸 수 있다.
final dataModeProvider = StateProvider<DataMode>((_) {
  final fromUrl = Uri.base.queryParameters['sample'] == '1';
  return Env.sampleData || fromUrl ? DataMode.sample : DataMode.live;
});

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return switch (ref.watch(dataModeProvider)) {
    DataMode.sample => SampleJournalRepository(),
    DataMode.live => ApiJournalRepository(ref.watch(apiClientProvider)),
  };
});

// ---------------------------------------------------------------------------
// 화면별 데이터
// ---------------------------------------------------------------------------

/// S01·S06이 함께 본다. `openSession`이 있으면 홈이 이어하기를 제안한다.
final meProvider = FutureProvider<Me>(
  (ref) => ref.watch(journalRepositoryProvider).me(),
);

/// S03 발견 목록 (§1-4 페이징의 첫 장).
final observationsProvider = FutureProvider<Paged<Observation>>(
  (ref) => ref.watch(journalRepositoryProvider).observations(),
);

/// S03-1 관찰 근거.
final evidenceProvider = FutureProvider.family<ObservationEvidence, String>(
  (ref, id) => ref.watch(journalRepositoryProvider).evidence(id),
);

/// S04가 보는 기간. 화면이 아니라 여기 두어야 다시 그려도 유지된다.
final trendRangeProvider = StateProvider<String>((_) => TrendRange.d30);

final trendProvider = FutureProvider<Trend>(
  (ref) => ref.watch(journalRepositoryProvider).trend(ref.watch(trendRangeProvider)),
);

/// S05 기록 목록.
final sessionsProvider = FutureProvider<Paged<SessionSummary>>(
  (ref) => ref.watch(journalRepositoryProvider).sessions(),
);

/// S05-1 대화 상세.
final sessionDetailProvider = FutureProvider.family<SessionDetail, String>(
  (ref, id) => ref.watch(journalRepositoryProvider).session(id),
);

// ---------------------------------------------------------------------------
// 대화 세션 (S02)
// ---------------------------------------------------------------------------

/// 지금 열려 있는 세션. S02가 시작하고 끝낼 때 지운다.
///
/// **`humeAccessToken`이 여기 담긴다** — 앱은 이 토큰으로만 EVI에 붙고,
/// 키를 내장하지 않는다 (FR-013). 샘플 모드에서는 가짜 값이 와서 붙지
/// 못한다 — 그게 샘플 모드의 목적이다.
final activeSessionProvider = StateProvider<SessionStart?>((_) => null);

/// 방금 끝낸 세션의 요약 — S02-1이 읽는다.
///
/// 종료 응답(§2-6)은 한 번만 오므로 화면 간에 들고 가야 한다. 목록을 다시
/// 불러 첫 항목을 쓰지 않는다 — 그건 "방금 끝낸 대화"라는 보장이 없다.
final lastSessionEndProvider = StateProvider<SessionEnd?>((_) => null);

/// S02 폴링 — 위기 신호(§2-13).
///
/// **간격은 서버가 준 `livePollIntervalSec`을 쓴다.** 앱에 상수로 박지 않는다.
/// 세션이 없으면 폴링하지 않는다.
final liveSignalProvider = StreamProvider<LiveSignal>((ref) async* {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return;
  final repo = ref.watch(journalRepositoryProvider);
  final every = Duration(seconds: session.livePollIntervalSec);
  while (true) {
    yield await repo.live(session.sessionId);
    await Future<void>.delayed(every);
  }
});

// ---------------------------------------------------------------------------
// 음성 (EVI)
// ---------------------------------------------------------------------------

/// EVI 소켓. **샘플 모드에서는 만들지 않는다** — 붙을 토큰 자체가 가짜다.
///
/// 화면이 직접 만들지 않고 여기서 주는 이유는 테스트에서 갈아끼우기 위함이다.
final eviServiceProvider = Provider.autoDispose<EviService>((ref) {
  final service = EviService(mic: RecordMic(), speaker: AudioPlayersSpeaker());
  ref.onDispose(service.dispose);
  return service;
});

/// EVI가 준 `chat_group_id` (F2-07의 `resumedChatGroupId` 원천).
///
/// **백엔드에 넘길 경로가 아직 없다** — `docs/request/app/chat-group-id.md`의
/// 3안(연결 직후 전송)으로 회신했고, 엔드포인트가 생기면 여기서 보낸다.
/// 지금은 같은 세션 안에서 재연결할 때만 쓰인다.
final chatGroupIdProvider = StateProvider<String?>((_) => null);
