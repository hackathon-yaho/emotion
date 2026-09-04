# app — 모바일 앱 (웹·iOS·Android)

담당: **앱**. **Flutter — 웹과 모바일 앱을 모두 지원하고, 배포는 웹으로 합니다** (PRD §14-4).

- 웹·iOS·Android 빌드가 하나의 코드베이스에서 나옵니다. **우선순위를 두지 않고 셋 다 도는 상태를 유지합니다.**
- **배포·도그푸딩·심사 시연·제출은 전부 같은 웹 URL**로 합니다. 화면은 웹·앱 모두 모바일 폭 기준입니다.
- 화면 정의는 [`spec.md`](../docs/00-context/spec.md) §4 · 시각 규약은 [`design-system.md`](../docs/01-product/design-system.md) · 호출 API는 [`api-contract.md`](../docs/02-architecture/api-contract.md) §2

## 실행

```bash
flutter pub get
flutter run -d chrome
```

**설정 파일이 필요 없습니다.** 환경변수는 `--dart-define`이고 기본값이 있습니다 — 자세한 값은 [`.env.example`](.env.example)에 적어 뒀습니다.

| 명령 | 용도 |
| --- | --- |
| `flutter analyze` | 정적 분석 — **이슈 0을 유지합니다** |
| `flutter test` | 토큰·스케일·「두 겹」 규약 회귀 테스트 |
| `flutter build web --release` | 웹 빌드. **배포 채널이라 항상 도는 상태로 유지합니다** |

## 팀원이 웹으로 보는 방법

**배포돼 있습니다 — https://hackathon-yaho.github.io/emotion/ 를 열면 됩니다.** Flutter가 없어도 보입니다. 아래는 그 외 방법입니다.

### ① 로컬 실행 (Flutter가 있는 사람)

```bash
git clone https://github.com/hackathon-yaho/emotion.git
cd emotion/app
flutter pub get
flutter run -d chrome
```

**설정 파일을 만들 필요가 없습니다.** 환경변수는 `--dart-define`이고 기본값이 있어서, 클론하고 바로 실행됩니다. (예전에는 `.env`가 없으면 빌드가 실패했습니다.)

백엔드에 붙일 때만 값을 줍니다.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.example.com
```

### ② GitHub Pages — 이미 켜져 있습니다

주소는 `https://hackathon-yaho.github.io/emotion/`이고, **제출용 링크도 이 주소를 그대로 씁니다.**

[`.github/workflows/app-web.yml`](../.github/workflows/app-web.yml)이 `app/` 변경 시 자동으로 빌드·배포합니다. `analyze`·`test`·`build`가 다 통과해야 배포되므로, **셋 중 하나라도 깨지면 배포가 멈춥니다.**

### ③ 정적 호스팅 (Vercel 등)

`flutter build web --release`의 `build/web`을 올리면 됩니다. **지금은 필요 없습니다** — Pages로 충분하고, 제출도 그 주소로 합니다. 커스텀 도메인은 제품 이름이 정해진 뒤에 붙입니다 (PRD §14-6).

## 백엔드에 붙이기 (CORS 정리됨, 2026-09-04)

`docs/response/app/cors-origin.md`로 정리된 것들입니다. **앱이 지킬 게 셋 있습니다.**

| 항목 | 값 | 앱이 할 일 |
| --- | --- | --- |
| 허용 오리진 | `https://hackathon-yaho.github.io` · `http://localhost:*` | **CORS 때문에 포트를 고정할 필요는 없습니다.** 다만 아래 카카오 때문에 로컬은 3000으로 띄웁니다 |
| 프리플라이트 | `OPTIONS`는 인증 없이 통과 | 없음. 백엔드가 JWT 필터 예외에 넣었습니다 |
| 자격증명 | **쓰지 않습니다** | **`withCredentials`를 켜지 않습니다** — 와일드카드 오리진과 함께 쓸 수 없습니다. 인증은 `Authorization` 헤더 하나입니다 |

백엔드 주소는 빌드 인자로 줍니다. 터널 URL도 같은 방법입니다.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://<터널>.ngrok.app
```

**CORS로 막히면 앱에는 그냥 네트워크 오류로 보입니다.** 배포 URL에서 모든 호출이 한꺼번에 실패하면 오프라인이 아니라 허용 오리진 목록(백엔드 환경변수 `CORS_ALLOWED_ORIGINS`)을 먼저 의심합니다 — `core/network/api_client.dart` 주석에 같은 메모를 남겨 뒀습니다.

**Hume EVI는 CORS와 무관하지만 순서상 뒤입니다.** 앱이 `wss://api.hume.ai`로 직접 붙긴 하는데, 그 연결에 쓰는 단기 토큰을 `POST /api/session/start`로 받아야 하므로 **CORS가 막히면 EVI도 시작하지 못합니다.**

## 카카오 로그인 — 로컬은 포트 3000입니다

**`flutter run -d chrome --web-port=3000`으로 띄웁니다.** 카카오 콘솔에 등록된 Redirect URI가 두 개뿐입니다.

```
https://hackathon-yaho.github.io/emotion/
http://localhost:3000/
```

**카카오 콘솔은 CORS와 달리 와일드카드를 받지 않습니다** — 문자열 완전 일치입니다. 포트가 다르면 **로그인만 실패하고 나머지 API는 멀쩡히 됩니다**(CORS가 `localhost:*`로 열려 있어서). 그래서 원인이 포트라는 걸 알아채기 어렵습니다.

흐름은 **인가 코드 방식**입니다 — [`docs/response/backend/kakao-web-login.md`](../docs/response/backend/kakao-web-login.md)에서 SDK 소스로 확정했습니다.

```
① S00 "카카오로 시작하기" → 인가 URL로 페이지 이동
② 동의 → 등록된 Redirect URI로 복귀 (?code=...)
③ 앱 시작 시 Uri.base의 code를 읽어 POST /api/auth/kakao
④ JWT 저장 → 게이트 통과 → 홈
⑤ 주소창의 ?code= 를 지운다 (history.replaceState)
```

**⑤를 빼먹으면 새로고침 때 쓴 코드를 다시 보내 400이 됩니다** — 인가 코드는 1회용입니다.

- **카카오 SDK를 넣지 않습니다.** `kakao_flutter_sdk` 2.0.1은 웹에서 `loginWithKakaoAccount()`·`issueAccessToken()`이 전부 예외를 던지고, `authorize()`도 `window.location.href`로 페이지를 넘긴 뒤 빈 문자열을 돌려줍니다. 웹에서 SDK가 하는 일은 URL 조립뿐입니다
- **경로 전략은 해시 라우팅을 유지합니다.** path 전략으로 바꾸면 Redirect URI를 다시 등록해야 하고 `404.html` 폴백도 필요해집니다

## 데이터는 어디서 오나

화면은 **`JournalRepository` 하나만** 봅니다. `Sample`도 `ApiClient`도 직접 보지 않습니다. 구현이 둘이라 화면 코드를 고치지 않고 갈아끼웁니다.

| 모드 | 구현 | 무엇을 타나 |
| --- | --- | --- |
| `live` (기본) | `ApiJournalRepository` | 백엔드 (계약 §2) |
| `sample` | `SampleJournalRepository` | **아무것도 안 탄다** — 준비된 데이터 |

### 샘플 모드 — 있는 이유는 Hume 과금입니다

**실제 Hume API를 켜 두고 테스트할 수 없습니다.** EVI는 통화 시간만큼 돈이 나가므로, 화면·흐름을 확인할 때마다 실제 세션을 열면 무료 한도가 개발 중에 사라집니다. 샘플 모드는

- 백엔드가 없어도 **11개 화면이 다 그려지고**,
- `startSession()`이 **가짜 Hume 토큰**(`sample-not-a-real-token`)을 주므로 앱이 EVI에 붙지 못하고 — 실수로 통화가 열릴 수 없습니다,
- `live()`가 **대본대로** 12초 뒤 위기 신호를 올려 **S07을 실제 위기 발화 없이** 확인할 수 있습니다.

켜는 방법 셋 중 아무거나 씁니다.

```bash
# ① 빌드 인자
flutter run -d chrome --dart-define=SAMPLE_DATA=true
```

```
② 주소에 붙이기 (배포된 URL에서도 됩니다 — 다시 빌드할 필요가 없습니다)
   https://hackathon-yaho.github.io/emotion/?sample=1

③ S06 설정 → 시연 → 샘플 데이터
```

**팀원이 백엔드 없이 전체 화면을 볼 때는 ②가 가장 빠릅니다.** 배포 워크플로는 repo variable `SAMPLE_DATA`를 읽으므로, 필요하면 배포 전체를 샘플로 돌릴 수도 있습니다.

> **샘플 데이터를 발표 근거로 쓰지 않습니다** (PRD §12). 화면 확인·시연 리허설 전용입니다. 시뮬레이션 그래프는 "직접 만드신 거죠?" 한 마디에 발견 기능 전체를 연출로 격하시킵니다.

### 프로바이더

`core/providers.dart`가 단일 출처입니다. 화면은 `ref.watch`만 합니다.

| 프로바이더 | 쓰는 화면 |
| --- | --- |
| `meProvider` | S01(이어하기 판단) |
| `observationsProvider` | S01 · S03 |
| `evidenceProvider(id)` | S03-1 |
| `trendRangeProvider` · `trendProvider` | S04 |
| `sessionsProvider` | S01 · S05 |
| `sessionDetailProvider(id)` | S05-1 |
| `activeSessionProvider` · `liveSignalProvider` | S02 |
| `lastSessionEndProvider` | S02-1 |

**로딩·빈 상태·오류는 `AsyncView`가 한 곳에서 처리합니다.** 특히 **오류를 빈 상태로 바꿔 말하지 않습니다** — "아직 발견한 것이 없습니다"는 사실 주장이라, 못 불러온 것을 그렇게 적으면 거짓이 됩니다.

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
│  ├─ data/journal_repository.dart  화면이 데이터를 얻는 유일한 경로
│  ├─ data/api_journal_repository.dart     실제 백엔드
│  ├─ data/sample_journal_repository.dart  샘플 모드 (Hume·백엔드 안 탐)
│  ├─ providers.dart        Riverpod 프로바이더 — 화면별 데이터
│  └─ fixtures/             샘플 데이터 (발표 근거로 쓰지 않는다)
├─ features/                화면 11개 (S00~S07) — 전부 구현됨
└─ shared/widgets/
   ├─ async_view.dart       로딩·빈 상태·오류 한 곳에서
   ├─ two_line_chart.dart   두 선 그래프 · 날짜 축 · 범례 (F9-01·02)
   ├─ tag_gap_bars.dart     이야기별 갭 막대 (F9-03)
   ├─ tab_pill.dart         하단 탭 알약 칩 (결정 24)
   ├─ app_frame.dart        넓은 화면 폭 규칙 — 여기 한 곳에서만 (§2)
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
| ~~F9-03 이야기별 갭~~ | ✅ 해결 — 계약 **v1.4** §2-8에서 `GET /api/trend`가 `tagGaps`·`userAvgGap`을 함께 줍니다(상위 7개, 3회 미만은 서버가 걸러냄, `range` 종속). **아직 앱 코드에 반영하지 않았습니다** |
| 산세리프 서체 | 문서상 Pretendard지만 Google Fonts에 없어 **Noto Sans KR로 대체** 중입니다(캔버스와 동일). `fonts/`에 넣고 `pubspec.yaml`의 fonts 항목을 켠 뒤 `AppType.sans`만 바꾸면 전 화면에 적용됩니다 |
| 제품 이름 | 미확정(PRD §14-6). Dart 패키지명 `voice_journal`, 번들 ID `com.hackathonyaho.voiceJournal`은 임시입니다. 확정되면 `main.dart`의 `title`과 `web/index.html`·`manifest.json`을 함께 고칩니다. **커스텀 도메인이 정해지면 백엔드에 알립니다** — 허용 오리진이 환경변수 한 줄이라 재배포 없이 들어갑니다 |
| 카카오 로그인 | 흐름은 확정(인가 코드)이지만 **키가 없어 아직 구현하지 않았습니다.** `onboarding_screen.dart`는 여전히 TODO입니다. **변수명이 `KAKAO_JS_KEY`로 남을지 `KAKAO_REST_KEY`가 될지는 백엔드 확인 1건에 달려 있습니다** — 정해지면 `env.dart`와 `app-web.yml`을 같이 고칩니다 |
| ~~데이터 연결~~ | ✅ 해결 — 화면이 `JournalRepository`를 봅니다. 기본은 실제 API이고, 샘플은 **샘플 모드에서만** 나옵니다(위 「데이터는 어디서 오나」) |
| 로그인 | 흐름은 확정(인가 코드)이고 **계약 v1.6 §2-1도 확정**인데 카카오 키가 없어 아직 구현하지 않았습니다. `POST /api/auth/kakao` 호출은 그래서 리포지토리에 없습니다 |
| EVI 음성 | `web_socket_channel`·`record`·`audioplayers`를 넣어두었고 **서비스는 아직 없습니다.** 세션 수립·폴링·종료까지는 실제로 돌고, `humeAccessToken`으로 EVI에 붙는 것이 다음 작업입니다 |

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
