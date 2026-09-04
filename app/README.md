# app — 모바일 앱 (웹·iOS·Android)

담당: **앱**. **Flutter — 웹과 모바일 앱을 모두 지원하고, 배포는 웹으로 합니다** (PRD §14-4).

- 웹·iOS·Android 빌드가 하나의 코드베이스에서 나옵니다. **우선순위를 두지 않고 셋 다 도는 상태를 유지합니다.**
- **배포·도그푸딩·심사 시연·제출은 전부 같은 웹 URL**로 합니다. 화면은 웹·앱 모두 모바일 폭 기준입니다.
- 화면 정의는 [`spec.md`](../docs/00-context/spec.md) §4 · 시각 규약은 [`design-system.md`](../docs/01-product/design-system.md) · 호출 API는 [`api-contract.md`](../docs/02-architecture/api-contract.md) §2

## 실행

```bash
cp .env.example .env   # 값을 채웁니다
flutter pub get
flutter run -d chrome
```

| 명령 | 용도 |
| --- | --- |
| `flutter analyze` | 정적 분석 — **이슈 0을 유지합니다** |
| `flutter test` | 토큰·스케일·「두 겹」 규약 회귀 테스트 |
| `flutter build web --release` | 웹 빌드. **배포 채널이라 항상 도는 상태로 유지합니다** |

## 구조

```
lib/
├─ main.dart                 진입점 — ProviderScope · 두 테마 · 라우터
├─ core/
│  ├─ config/env.dart        환경변수 (하드코딩 금지, 계약서 §1-1)
│  ├─ theme/tokens.dart      디자인 토큰 — design-system §4가 단일 출처
│  ├─ theme/typography.dart  명조 + 산세리프, 타입 스케일 (§3)
│  ├─ theme/app_theme.dart   다크·라이트 ThemeData
│  ├─ router/routes.dart     화면 ID ↔ 경로 (spec §4와 1:1)
│  ├─ router/app_router.dart go_router — 셸 라우트 + 단독 화면
│  ├─ network/api_client.dart Dio · 오류 규약 · 401 처리
│  ├─ network/endpoints.dart 계약서 §2 경로
│  ├─ storage/token_storage.dart JWT · 온보딩 플래그 (secure storage)
│  ├─ models/               계약서 §2 응답 타입 (null 규칙 포함)
│  └─ providers.dart        Riverpod 프로바이더
│  └─ fixtures/            화면용 샘플 데이터 (발표 근거로 쓰지 않는다)
├─ features/                화면 11개 (S00~S07) — 전부 구현됨
└─ shared/widgets/
   ├─ two_line_chart.dart   두 선 그래프 · 날짜 축 · 범례 (F9-01·02)
   ├─ tag_gap_bars.dart     이야기별 갭 막대 (F9-03)
   ├─ ring_pair.dart        S02의 어긋난 두 링
   ├─ doubled_text.dart     「두 겹」 — 그림자 한 겹으로
   ├─ kakao_button.dart     카카오 규격 (우리 규칙의 예외)
   ├─ confirm_sheet.dart    파괴적 동작 확인 (care 색 금지)
   └─ 헤어라인 · 빈 상태 · 스켈레톤 · 앱 셸 · 메타 행 · 버튼
```

## 지켜야 하는 것

- **S07은 `crisisDetected`의 `false → true` 전이에서 한 번만** 띄웁니다. 폴링이 계속 true를 줘도 다시 띄우지 않습니다 (계약 §2-13)
- **`GET /live`의 `turns: []`는 "볼 권한이 없다"이지 "값이 없다"가 아닙니다.** 비데모 세션에서는 항상 빈 배열이고, `null`(측정 못함)과 뜻이 다릅니다

- **S02 대화 화면에 valence·갭 수치를 그리지 않습니다.** `demoMode == true`일 때만 예외 (FR-031)
- **감정에 반응하는 색을 쓰지 않습니다.** 두 링은 색이 고정이고 간격·크기·투명도만 상태에 반응합니다 — 색이 변하면 사실상 갭 노출입니다 (FR-030)
- **차가운 색 = 말한 내용, 따뜻한 색 = 목소리.** 제품 전체에서 같은 의미로만 씁니다
- **`care` 색은 S07 전용입니다.** 파괴적 동작(탈퇴·삭제)에 쓰지 않습니다
- **Hume API 키를 앱에 내장하지 않습니다.** 백엔드가 발급하는 단기 토큰만 씁니다 (FR-013). **웹은 번들이 전부 공개되므로 더 엄격합니다**
- `softWrapSec`·`hardCutSec`을 상수로 박지 않습니다. 서버 응답값을 씁니다 (계약서 §2-4)
- 음성 파일을 쓰지 않습니다 — `.wav`·`.mp3` 저장이나 오디오 업로드 코드가 어디에도 없어야 합니다 (FR-041, TC-11)
- 그래프에서 **기록이 없는 날은 선을 끊습니다.** 보간하지 않습니다 (계약서 §1-3)
- **대화 중 401은 대화를 끊지 않습니다.** 다음 요청부터 갱신합니다 (F1-02) — `inConversationProvider`가 그 신호입니다

## 아직 임시인 것

| 항목 | 상태 |
| --- | --- |
| ~~`HUME_CONFIG_ID`~~ | ✅ 해결 — 계약 v1.3 §2-4의 `humeConfigId`로 옵니다. 백엔드가 기동 시 fail-fast로 검증하므로 **null이 될 수 없고 앱은 폴백을 두지 않습니다** |
| ~~S07 트리거~~ | ✅ 해결 — 계약 v1.3 §2-13 `GET /api/session/{id}/live` 폴링. 간격은 `livePollIntervalSec`(기본 2초)를 따릅니다 |
| F9-03 이야기별 갭 | 출력이 계약 어디에도 없습니다 — [`tag-gap-endpoint.md`](../docs/request/backend/tag-gap-endpoint.md) (⏳). S04의 두 선 그래프는 영향 없습니다 |
| 산세리프 서체 | 문서상 Pretendard지만 Google Fonts에 없어 **Noto Sans KR로 대체** 중입니다(캔버스와 동일). `fonts/`에 넣고 `pubspec.yaml`의 fonts 항목을 켠 뒤 `AppType.sans`만 바꾸면 전 화면에 적용됩니다 |
| 제품 이름 | 미확정(PRD §14-6). Dart 패키지명 `voice_journal`, 번들 ID `com.hackathonyaho.voiceJournal`은 임시입니다. 확정되면 `main.dart`의 `title`과 `web/index.html`·`manifest.json`을 함께 고칩니다 |
| 데이터 연결 | 화면은 `core/fixtures/sample_data.dart`의 **샘플로 그립니다.** API가 붙으면 프로바이더로 바꿉니다 — 샘플은 발표 근거로 쓰지 않습니다(PRD §12) |
| EVI 음성 | `web_socket_channel`·`record`·`audioplayers`를 넣어두었고 서비스는 아직 없습니다. 다음 작업입니다 |

## 디자인 캔버스

`design/`에 아트보드 작업 파일이 있습니다. 재생성·구현 규칙은 [`design/README.md`](design/README.md).

## EVI 연결 메모 (공식 예제 실측, 2026-09-03)

```
wss://api.hume.ai/v0/evi/chat?access_token={humeAccessToken}&config_id={humeConfigId}&custom_session_id={sessionId}
```

- `access_token` — 계약서 §2-4의 `humeAccessToken`
- `config_id` — `session/start` 응답의 `humeConfigId` (계약 v1.3 §2-4)
- `custom_session_id` — 예제에 없어 우리가 추가합니다 (spec F2-02, CLM 계약 §4)
- **`session_settings`에 `language_model_api_key`를 넣지 않습니다** — 웹 번들에 노출되므로, CLM 인증은 AI서버가 `custom_session_id`를 백엔드로 검증하는 방식입니다 (`ai-pipeline.md` AI-11)
- 연결 성공 시 `chat_metadata`로 `chat_group_id`가 옵니다 → F2-07 이어하기의 `resumedChatGroupId` 원천
- **공식 예제의 오류 처리는 그대로 쓰지 않습니다.** 인증 실패·마이크 거부에서 처리되지 않은 예외를 던져 F2-04 수용 기준("어떤 경우에도 앱이 멈추지 않는다")을 못 지킵니다

---

이 폴더에 대한 요청은 `../docs/request/app/`, 앱이 보낸 요청의 회신은 `../docs/response/app/`.
