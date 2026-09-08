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

> ### 배포본이 라이브입니다 (2026-09-06)
>
> `SAMPLE_DATA` 저장소 변수를 **껐습니다.** 배포된 링크는 이제 **실제 백엔드와 실제 Hume**에 붙습니다 — 「오늘 이야기하기」를 누르면 진짜 통화가 열립니다.
>
> **Hume 무료 플랜은 월 5분 · 동시 접속 1**입니다. 두 사람이 동시에 시작하면 뒤에 누른 쪽이 `E0700`으로 거절당하고, 서버 대기열은 기본이 꺼져 있어 줄도 서지 않습니다. **시연 전에 남은 분수를 확인하세요.**
>
> 다시 샘플로 돌리려면 변수를 켜고 재빌드하면 됩니다.
>
> ```sh
> gh variable set SAMPLE_DATA --body true --repo hackathon-yaho/emotion
> gh workflow run app-web.yml --repo hackathon-yaho/emotion
> ```


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

### 로그인 (F1-01) — 값만 기다립니다

```
① S00 "카카오로 시작하기" → 인가 URL로 페이지 이동
   https://kauth.kakao.com/oauth/authorize?client_id={KAKAO_REST_KEY}&redirect_uri={등록값}&response_type=code
② 동의 → 등록된 Redirect URI로 복귀 (?code=...)
③ 앱 시작 시 Uri.base의 code를 POST /api/auth/kakao
④ JWT 저장 → 게이트 통과 → 홈
⑤ 주소창의 ?code= 를 지운다 (history.replaceState)
```

- **`redirectUri`는 인가 때 쓴 값과 문자 단위로 같아야 합니다.** `KakaoLogin.redirectUriFrom`이 파일명·쿼리·해시를 떼어 등록값(`.../emotion/`, `http://localhost:3000/`)과 같은 모양을 만듭니다 — **끝의 빈 조각을 안 버려 `//`가 되던 버그를 테스트가 잡았습니다.** 어긋나면 400만 나오고 원인이 보이지 않는 자리입니다
- **돌아온 직후에는 카카오 버튼을 그리지 않습니다.** 주소에 코드가 실려 있으면 **첫 프레임부터** "로그인하고 있습니다"로 바꿉니다 — 버튼을 그대로 두면 사용자는 로그인이 실패해서 처음으로 되돌아온 줄 압니다. 흐린 버튼으로 두지도 않습니다: 눌러도 되는 것처럼 보이면 두 번 누르게 되고 **인가 코드는 1회용**이라 두 번째는 400입니다
- **⑤를 빼먹으면 새로고침이 같은 코드를 다시 보내 400입니다** — 인가 코드는 1회용입니다. 지운 뒤에 로그인을 완료합니다
- **키가 없으면 버튼이 조용히 죽지 않습니다.** 눌렀는데 아무 일도 없으면 버그로 보이므로 문구로 안내합니다
- 샘플 모드에서는 카카오에 가지 않고 그 자리에서 통과시킵니다

### 세션 길이 (F2-03)

`session/start`가 주는 `hardCutSec`으로 타이머 두 개를 겁니다 — **60초 전** 조용한 표시, **하드컷**에서 자동 종료(`endReason: hard_cut`). **소프트 랩(5분)에는 화면이 아무것도 하지 않습니다** — AI가 말로 유도하므로 UI가 개입하면 두 번 재촉합니다(§7 결정 1). 이어하기는 잔여 시간이 들어오므로 **1분 이하로 남았으면 표시를 즉시** 띄웁니다(60을 빼서 음수가 되면 표시가 통째로 빠집니다).

### JWT 만료 (F1-02)

`ApiClient.onTokenExpired`가 `inConversationProvider`를 봅니다. **대화 중이면 내보내지 않고** 표시만 해두었다가(`pendingSignOutProvider`) 대화가 끝난 뒤에 로그아웃합니다 — 7분 안에 만료가 겹치는 일은 드물지만, 겹쳤을 때 화면이 로그인으로 튀면 하던 말이 사라집니다.

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
| `chatGroupIdProvider` | S02 — EVI가 준 값을 §2-5-2로 올린다 |
| `themeModeProvider` · `demoModeProvider` | S06 — **저장됩니다**(기기 저장소) |
| `pendingSignOutProvider` | F1-02 — 대화 중 만료를 미뤄 두는 표시 |
| `lastSessionEndProvider` | S02-1 |

목록(S03·S05)은 `PagedNotifier`가 **바닥에 닿으면 다음 장을 이어 붙입니다** — "더 보기" 버튼이 없습니다(§7 결정 22). 다음 장을 못 불러와도 **이미 보여준 목록을 오류로 바꾸지 않습니다.**

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
│  ├─ voice/evi_service.dart  Hume EVI 소켓 — 프로토콜·실패 처리
│  ├─ voice/mic.dart · speaker.dart  마이크(PCM16 스트림) · 재생 큐
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
| 제품 이름 | 미확정(PRD §14-6). Dart 패키지명 `voice_journal`, 번들 ID `com.hackathonyaho.voiceJournal`은 임시입니다. 확정되면 `main.dart`의 `title`과 **`web/index.html`의 `<title>`·`apple-mobile-web-app-title`, `manifest.json`의 `name`·`short_name`** 을 함께 고칩니다. **커스텀 도메인이 정해지면 백엔드에 알립니다** — 허용 오리진이 환경변수 한 줄이라 재배포 없이 들어갑니다 |
| 카카오 로그인 | **흐름은 다 구현했습니다** — 인가 URL 조립·복귀 시 `?code=` 교환·주소창 정리까지. **값만 없습니다**(`KAKAO_REST_KEY` repo variable). 키가 없으면 버튼이 조용히 죽지 않고 "아직 로그인을 켤 수 없습니다"를 띄웁니다 |
| ~~데이터 연결~~ | ✅ 해결 — 화면이 `JournalRepository`를 봅니다. 기본은 실제 API이고, 샘플은 **샘플 모드에서만** 나옵니다(위 「데이터는 어디서 오나」) |
| ~~제출 전 필수~~ | ✅ 해결 — `SAMPLE_DATA`를 껐습니다(2026-09-06). 배포본이 실제 백엔드·Hume에 붙습니다 |
| 로그인 | 흐름은 확정(인가 코드)이고 **계약 v1.6 §2-1도 확정**인데 카카오 키가 없어 아직 구현하지 않았습니다. `POST /api/auth/kakao` 호출은 그래서 리포지토리에 없습니다 |
| EVI 음성 | 구현·검증했습니다(`core/voice/`, 테스트 19건 + 가짜 EVI 서버 왕복). **Hume 실서버 왕복만 남았습니다** — 로그인해서 받는 단기 토큰이 있어야 합니다 |

## 디자인 캔버스

`design/`에 아트보드 작업 파일이 있습니다. 재생성·구현 규칙은 [`design/README.md`](design/README.md).

## 음성 (EVI) — 구현했습니다

```
wss://api.hume.ai/v0/evi/chat?access_token={humeAccessToken}&config_id={humeConfigId}&custom_session_id={sessionId}
```

`core/voice/`에 있습니다. `EviService`가 소켓·프로토콜, `Mic`이 마이크, `Speaker`가 재생입니다. **셋 다 인터페이스라 테스트에서 갈아끼웁니다** — `test/evi_test.dart` 17건이 가짜 소켓으로 핸드셰이크·수신·실패·종료를 검증합니다.

| 값 | 출처 |
| --- | --- |
| `access_token` | `session/start` 응답의 `humeAccessToken` (**단기 토큰**) |
| `config_id` | 같은 응답의 `humeConfigId` (v1.3 §2-4) |
| `custom_session_id` | `sessionId` — AI서버가 이 값으로 세션을 검증합니다 (계약 §4) |
| `resumed_chat_group_id` | 이어하기일 때만 (F2-07) |

### 코드에 못 박아 둔 것

- **Hume 키를 앱에 두지 않습니다** (FR-013). 소켓에 들어가는 것은 백엔드가 발급한 단기 토큰뿐입니다
- **`language_model_api_key`를 `session_settings`에 넣지 않습니다** — 웹 번들에 노출됩니다. CLM 인증은 AI서버가 `custom_session_id`를 검증하는 방식입니다 (계약 §4). **테스트가 이 문자열이 나가지 않는지 확인합니다**
- **프로소디를 파싱하지 않습니다.** `user_message`에 48종 점수가 실려 오지만 앱은 텍스트만 꺼냅니다 — 사건 클래스에 점수를 담을 자리 자체가 없습니다. 들고 있으면 언젠가 화면에 나옵니다 (FR-030·031)
- **음성을 파일로 쓰지 않습니다** (FR-041). `record`의 `startStream`으로 바이트를 받아 소켓으로만 보내고, 재생 조각은 메모리에서 버립니다. `start(path:)` 계열을 쓰면 그 순간 규칙이 깨집니다
- **어떤 실패에서도 예외를 밖으로 던지지 않습니다** (F2-04 수용 기준). 전부 `EviFailed`로 내려가고 화면이 원인별 문구를 고릅니다 — 마이크 거부만 사용자가 고칠 수 있으므로 문구가 다릅니다
- **분류하지 못한 오류를 `auth`로 뭉개지 않습니다.** "다시 시도"가 소용없는 상황에서 다시 시도를 권하게 됩니다
- **소켓을 먼저 열고 마이크를 나중에 켭니다.** 순서를 뒤집으면 인증 실패인데도 마이크 권한 창이 먼저 떠서 사용자가 원인을 오해합니다
- **`user_interruption`에서 재생 큐를 비웁니다.** 안 비우면 사용자가 끊었는데도 AI가 계속 말합니다
- **자막을 쌓지 않습니다** (design-system §6-1). 사용자 발화만 3초간 띄우고, AI 발화는 텍스트로 그리지 않습니다 — 소리로 듣는 것을 글로 또 보여주면 채팅앱이 됩니다

### 마이크 왕복 — 앱 구간은 검증했습니다 (2026-09-06)

헤드리스 크롬의 **가짜 마이크**와 **가짜 EVI 서버**로 왕복을 돌렸습니다. Hume 토큰 없이 확인할 수 있는 전 구간입니다.

| 확인 | 결과 |
| --- | --- |
| 마이크 열림 | ✅ `getUserMedia` → AudioWorklet |
| 형식 | ✅ `session_settings`가 **먼저** 나가고 `linear16 · 16000 · 1` |
| 전송 | ✅ `audio_input` **356프레임 · 529KB**, base64가 유효한 PCM16 (14초 · 16kHz) |
| 수신 | ✅ `user_message` · `assistant_message` · `audio_output` |
| 재생 | ✅ 앱이 WAV를 디코드해 **재생을 시작**(`play()` 호출을 후킹해 확인) |

**Hume 실서버 왕복은 아직입니다** — 그쪽은 로그인해서 받은 단기 토큰이 있어야 열립니다. 여기서 확인한 것은 **우리 쪽 전 구간**이고, Hume 프로토콜 자체는 `test/evi_test.dart` 19건이 가짜 소켓으로 봅니다.

**검증하다 실제 결함을 하나 잡았습니다.** `eviServiceProvider`가 `autoDispose`였는데 화면이 `ref.read`로 집으면 듣는 사람이 없어 **읽자마자 폐기**됐습니다. 폐기가 `mic.close()`를 부르고, 그 뒤 `startStream`이 죽은 레코더에 걸리는데 **이벤트 스트림도 이미 닫혀 있어 화면은 실패조차 듣지 못했습니다** — 마이크가 조용한 채 "듣고 있습니다"로 대화가 흘러가는 모양입니다. 단위 테스트로는 안 보이고 **소켓에 프레임이 한 건도 안 오는 것**으로 드러났습니다. 회귀 테스트를 넣었습니다.

#### 다시 돌리는 방법

```bash
flutter build web --release \
  --dart-define=SAMPLE_DATA=true \
  --dart-define=EVI_WS_URL=ws://localhost:8110/chat
```

`EVI_WS_URL`은 **개발·검증 전용**입니다 — 비어 있으면 항상 `wss://api.hume.ai`이고, 배포 빌드에는 값이 없습니다. 크롬은 `--use-fake-ui-for-media-stream --use-fake-device-for-media-stream`로 띄웁니다. **`--use-file-for-fake-audio-capture`에 `%noloop`을 붙이면 `NotReadableError`로 마이크가 안 열립니다** — 파일을 쓸 거면 접미사 없이 쓰고, 그마저도 무음이 나와서 저는 크롬 내장 톤을 썼습니다.

---

이 폴더에 대한 요청은 `../docs/request/app/`, 앱이 보낸 요청의 회신은 `../docs/response/app/`.

## 대화가 이상할 때 — 책임을 가르는 진단 한 줄

`SHOW_ERROR_DETAIL=true`로 빌드하면 대화 화면 상태 문구 아래에 이 줄이 붙습니다.

```
마이크 11 (최대 98) · AI 발화 2 · 조각 2 · 끼어들기 0
```

- **마이크** — 지금 보내고 있는 소리의 크기(0~100)와 최대값. **말하는데 0에 가까우면 캡처가 우리 쪽에서 깨진 것**입니다. 값이 멀쩡하면 소리는 나가고 있습니다
- **AI 발화 · 조각** — 받은 `assistant_message` 수와 오디오 조각 수. 조각만 늘고 소리가 멈추면 **우리 재생**입니다
- **끼어들기** — `user_interruption` 수. 아무 말도 안 했는데 늘면 Hume의 VAD가 스피커 소리를 사용자 말로 들은 것입니다(에코)

**계측을 만들었으면 반드시 화면에 붙입니다.** 이 줄은 클래스만 만들어 두고 붙이는 것을 잊은 채로 "숫자를 보세요"라고 말한 적이 있습니다 (2026-09-06).

### 실제로 이 줄로 가른 것

「지금은 제가 잘 듣지 못했어요」가 반복된 건 **마이크가 아니라 AI서버의 LLM 호출 실패**였습니다 — 그 문장은 `ai-server/app/llm/respond.py`의 `FALLBACK`이고 실패 경로에서만 나옵니다. 앱 쪽 오디오는 가짜 EVI 서버로 받아 재봤습니다: 22.4초에 717,464바이트(**16k 모노 PCM16과 일치**), RMS 평균 1013·최대 10711(**무음이 아님**). `docs/request/ai/respond-fallback.md`로 넘겼습니다.

**링에는 목업 발화를 넣지 않습니다.** 디자인 프로토타입 때 넣은 "오늘 완전 괜찮았어요"가 실제 대화에서 계속 떠 있었습니다. 그 자리에는 실제로 들은 말(`_heard`)만 옵니다.

## 화면의 숫자는 전부 서버 값이다

시안에서 옮겨온 숫자가 상수로 박힌 채 배포돼 있었습니다 (2026-09-07 발견).

| 자리 | 박혀 있던 값 | 지금 |
| --- | --- | --- |
| 홈 이어하기 — 중단 시각 | `5분 전` | `startedAt + usedSec`으로부터 `SessionClock.ago()` |
| 홈 이어하기 — 남은/원래 | `4분 42초` · `7분` | `remainingSec` · `usedSec + remainingSec` |
| 대화 — 이어하기 링 | `남은 시간 4분 42초` | 이어하기 응답의 `remainingSec` |
| 기록 상세 — 자동 종료 | `7분에 자동으로 마무리됐습니다` | 그 세션의 `durationSec` |

**시간을 화면에 적을 때는 `SessionClock.spell()`·`ago()`를 씁니다.** 직접 `분`·`초`를 조립하면 같은 사고가 다시 납니다. `7분`(하드컷)은 **서버가 정하는 값**이라 앱에 상수로 두지 않습니다 (계약 §2-4) — 이어하기한 세션은 7분이 아닙니다.

`EviService`의 진단 계수기도 `start()`마다 0으로 돌립니다. 이 서비스는 앱 수명 내내 사는 한 개짜리라, 안 지우면 **두 번째 대화 화면에 첫 대화의 턴 수가 얹혀** 보입니다.

## 서체 — Pretendard는 번들, 명조는 런타임

산세리프는 **앱에 넣어 둡니다**(`fonts/Pretendard-Regular.otf`, 서브셋 1.27MB).
**CanvasKit이 글자를 직접 그리므로 브라우저 CSS 서체(`@font-face`)는 적용되지
않습니다** — `pubspec.yaml`에 등록해야 합니다. 종전에는 Google Fonts에 없는
서체라 Noto Sans KR로 대체하고 런타임에 받고 있었는데, 그건 약 5MB이고
네트워크가 없으면 영영 오지 않습니다.

명조(Gowun Batang)는 계속 런타임에 받습니다. **서브셋해도 8.1MB**라 번들할
값이 없습니다. 첫 화면에서 명조 글자가 잠깐 다른 서체로 보일 수 있습니다.

## 탈퇴하면 카카오 연결도 끊습니다 (F10-03)

계약 §2-3은 `DELETE /api/account` 본문에 `kakaoAuthCode`를 실으면 백엔드가
데이터를 지운 뒤 카카오 연결까지 끊는다고 정합니다. 그 코드를 받으려면 **탈퇴를
누른 자리에서 인가를 한 번 더 통과**해야 합니다 — 우리는 카카오 토큰을 보관하지
않기 때문입니다(그게 "저장하는 것은 회원번호 하나"라는 제품 주장의 근거입니다).

웹은 인가 페이지로 나갔다가 **앱이 통째로 다시 뜹니다.** 그래서 돌아온 코드가
로그인용인지 탈퇴용인지 주소만으로는 알 수 없습니다. 나가기 전에 저장소에
표시를 남기고(`TokenStorage.markPendingUnlink`), 부팅 시 `main.dart`에서
`finishUnlinkIfReturned`가 그 표시를 보고 가릅니다.

- **취소하면 아무것도 지우지 않습니다.** 동의 화면에서 되돌아온 것은 탈퇴를
  그만둔 것입니다
- **표시는 요청 전에 지웁니다.** 남으면 다음 로그인 복귀를 탈퇴로 오해합니다
- **실패하면 기기를 비우지 않습니다.** 비우면 서버에 남은 데이터를 지울 방법이
  없어집니다

**⚠️ 이 왕복은 실제 계정으로만 끝까지 확인할 수 있습니다** — 확인하는 순간
데이터가 진짜로 지워집니다. 그래서 갈림 로직만 테스트로 잠갔고
(`test/account_unlink_test.dart` 6건), 실제 왕복은 도그푸딩 마지막에 확인합니다.

## 첫 인사 동안 마이크를 보류합니다 (2026-09-08)

EVI Config에 첫 인사말이 있어 **연결되면 AI가 먼저 말합니다.** 그런데 화면이
곧바로 「듣고 있습니다」가 되면 사용자는 그때 말을 시작하고, Hume이 그것을
끼어들기로 읽어 **인사를 도중에 끊습니다.** 스피커 소리가 마이크로 되돌아가도
같은 일이 납니다.

새 대화의 순서를 이렇게 바꿨습니다.

```
연결하고 있습니다 → 말하고 있습니다 → (재생이 빈 뒤) 듣고 있습니다
```

- **마이크는 열어 두고 소리만 안 보냅니다.** 권한 창이 인사 도중에 뜨면 그게
  더 나쁩니다. 계측은 계속하므로 진단 줄의 `마이크` 값은 그대로 오릅니다
- **여는 시점은 `assistant_end`가 아니라 재생 큐가 빈 뒤**입니다. 그 프레임은
  "조각을 다 보냈다"는 뜻일 뿐이라, 그때 열면 남은 인사가 마이크로 돌아와
  **자기 말을 끊습니다**
- **보류는 첫 턴 한 번뿐입니다.** 그 뒤의 끼어들기는 기능입니다
- **12초면 무조건 엽니다.** 인사가 없는 Config에서 영영 안 열리면 대화가
  통째로 죽습니다. 이어하기는 인사가 없으므로 보류하지 않습니다

**`_enter`가 연결 전에 이미 `listening`으로 바꿔 놓고 있었습니다** — 사건
처리만 고치고 여기를 놓쳐서 첫 수정이 화면에 아무 효과가 없었습니다. 상태를
정하는 자리가 둘이면 나중 것이 이깁니다.

검증은 가짜 EVI 서버가 **실제처럼 먼저 인사하게** 만들어서 했습니다
(`fake-evi.mjs`). 인사 중에는 `audio_input`이 0건이고, 첫 프레임은
`assistant_end` **뒤 220~240ms**에 나갑니다. 화면도 인사 중 「말하고
있습니다」 · `끼어들기 0`으로 찍혔습니다.

## 「말 다 했어요」 — 사용자가 자기 턴을 끝냅니다 (2026-09-08)

Hume은 침묵 **1.8초**(`end_of_turn_silence_ms`)를 봐야 턴을 확정합니다. 그
사이 숨소리·주변 소음·"음…"이 들어가면 **턴이 계속 열려 한참 기다립니다.**

**EVI에는 턴을 강제로 끝내는 클라이언트 메시지가 없습니다.** 공식 문서의
클라이언트 메시지는 `audio_input`·`user_input`·`session_settings`·
`assistant_input` 넷뿐이고, `turn_detection`은 **Config 전용**이라 세션
설정으로 바꿀 수 없습니다. 그래서 버튼이 하는 일은 **소리 전송을 끊어 침묵을
만들어 주는 것**입니다.

- 확정까지 **1.8초는 그대로 걸립니다.** 대신 화면이 **곧바로** 「생각 중」으로
  가고, 잡음이 턴을 늘리지 못합니다
- 마이크는 **AI의 답이 끝나고 재생이 빈 뒤** 다시 열립니다 (인사 보류와 같은
  장치). 답이 아예 오지 않아도 15초면 엽니다
- 「조금 오래 걸리고 있습니다」의 4초는 **누른 시점 + 1.8초**부터 셉니다 —
  Hume이 기다리는 시간을 우리 지연으로 세면 매번 그 문구가 뜹니다

**인사 보류를 2.5초로 줄였습니다.** 12초로 뒀던 것이 잘못이었습니다 — 인사가
오지 않는 경우(Config·계정 문제, 이어하기) **사용자가 12초 동안 말해도 한
마디도 전달되지 않습니다.** 이제 인사가 **시작될** 때까지만 2.5초 기다리고,
시작되면 끝날 때까지(상한 15초) 기다립니다.

## 대화 시간 숫자는 서버 값입니다

요약·기록에 보이는 `N분 N초`는 `durationSec`을 그대로 쓴 것입니다. **계약서에
계산 방식이 없어** 벽시계인지 누적 발화 시간인지 알 수 없고, 실사용에서
**잠깐 한 대화가 10분으로** 나왔습니다. `hardCutSec`(420초)보다 큰 값이 나오는
것은 대화 시간이라면 모순이므로, 정의를 물었습니다 —
`docs/request/backend/duration-definition.md`. **앱이 다른 숫자를 만들어 쓰지는
않습니다.**
