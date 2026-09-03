/// 화면 ID ↔ 경로. spec §4 화면 정의서와 1:1로 맞춘다.
///
/// 화면 ID(S00~S07)는 문서 식별자로 유지하고, 사용자에게 보이는 탭 라벨은
/// 오늘·발견·추세·기록이다 (design-system §7-6).
abstract final class Routes {
  /// S00 진입 · 로그인
  static const onboarding = '/';

  /// S01 홈 — 탭 라벨 "오늘"
  static const home = '/today';

  /// S02 대화
  static const conversation = '/conversation';

  /// S02-1 대화 종료 요약
  static const summary = '/conversation/summary';

  /// S03 발견
  static const discover = '/discover';

  /// S03-1 관찰 근거
  static const evidence = '/discover/:observationId';
  static String evidenceOf(String id) => '/discover/$id';

  /// S04 감정 트렌드 — 탭 라벨 "추세"
  static const trend = '/trend';

  /// S05 대화 기록
  static const records = '/records';

  /// S05-1 대화 상세
  static const recordDetail = '/records/:sessionId';
  static String recordDetailOf(String id) => '/records/$id';

  /// S06 설정
  static const settings = '/settings';

  /// S07 위기 안내 — 대화 화면 위 오버레이. 라우트가 아니라 시트로 띄운다.
  /// (계약서 §5: "없음 — 앱 로컬 표시")
}

/// 하단 탭 — 홈 / 발견 / 추세 / 기록 (spec §4 공통 요소).
enum AppTab {
  home(Routes.home, '오늘'),
  discover(Routes.discover, '발견'),
  trend(Routes.trend, '추세'),
  records(Routes.records, '기록');

  const AppTab(this.path, this.label);
  final String path;
  final String label;
}
