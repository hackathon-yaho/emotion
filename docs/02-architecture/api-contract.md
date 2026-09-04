# API 계약서 — 감정 케어 보이스 저널

> **수정 기록 (2026-09-05 ⑦, 백엔드)** — **v1.9.** Hume의 **동시 접속 상한**(요금표 실측: Free 1 / Starter·Creator 5 / Pro 10)에 6번째 사용자가 걸리면 **Hume은 줄을 세우지 않고 `E0700`으로 거절한다.** 대기 순번을 보여주려면 대기열을 우리가 만들어야 한다(팀장 결정). ① **§2-14 신설** — `GET`·`DELETE /api/session/queue/{ticketId}`. **`position`이 0인 응답에 세션이 실려 오고 그 응답 자체가 입장권이다** — 자리를 예약해 두지 않으므로 만료 타이머도 가로채기도 없다 ② **§2-4에 202 응답 추가** — 정원이 차면 201 대신 202 + 순번. **기본은 꺼짐이라 202가 나갈 일이 없다** ③ 정원 판정은 **Hume의 `GET /v0/evi/chats?status=ACTIVE`**로 한다. 우리 세션 행을 세면 안 된다 — **Hume은 비활성 2분에 채팅을 닫는데 `voice_session`은 30분을 열어 두므로, 실제로 비어 있는 자리를 두고 사람을 돌려보낸다.** §5 S02 행 갱신. **필드 추가·삭제·개명 없음**(엔드포인트 2개 신설).
>
> **수정 기록 (2026-09-05 ⑥, 백엔드)** — **v1.8.** 앱 회신(`request/app/chat-group-id.md`)으로 **`chat_group_id`가 소켓이 열린 직후 `chat_metadata`로 온다**는 것이 확정됐다. ① **§2-5-2 `POST /api/session/{sessionId}/chat-group` 신설** — 앱이 값을 받은 즉시 올린다. **멱등·204**이며, 강제 종료로 `end`를 못 부른 세션까지 덮는 유일한 경로다(그리고 이어하기가 필요한 상황이 정확히 그 상황이다) ② **§2-5-1 `resumedChatGroupId`의 빈 값을 `null`로 확정** — 앱이 빈 문자열로 방어 중이었다. §1-3에 행을 추가했다. **필드 추가·삭제·개명 없음**(엔드포인트 1개 신설). §5 S02 행도 갱신했다.
>
> **수정 기록 (2026-09-05 ⑤, 백엔드)** — **v1.7.** 앱 요청(`request/backend/session-id-in-url.md`) 회신 — **`sessionId`의 앱 URL 프래그먼트 노출을 허용하고 그 근거를 §1-1에 명시**했다. 로그 금지와 모순되지 않는 이유는 **주소창에 오는 ID가 구조적으로 죽은 값**이기 때문이다: 기록 목록이 끝난 세션만 주고(§2-9), 끝난 세션은 CLM 401이며(§3-4), 이어하기로도 살아나지 않는다(§2-5-1). 셋 다 실측했다. **해시 라우팅이 전제**라는 조건과 **path 전략으로 바꾸면 무효**라는 것도 같이 적었다. **필드 추가·삭제·개명 없음.**
>
> **수정 기록 (2026-09-05 ④, 백엔드)** — **v1.6.** 앱 회신(`response/backend/kakao-web-login.md`)으로 **웹에서는 앱이 카카오 액세스 토큰을 받을 수 없다**는 것이 확정됐다(SDK 2.0.1 소스: 웹 로그인 API가 전부 `notSupported`, `authorize()`는 리다이렉트 후 빈 문자열). **§2-1 요청을 `kakaoAccessToken` → `kakaoAuthCode` + `redirectUri`로 교체**하고, **§2-3에 탈퇴 unlink용 선택 본문**을 넣었다. **이 회차의 유일한 필드 삭제는 `kakaoAccessToken`이고 앱·백엔드가 같이 맞춘다.** 응답은 §2-1·§2-3 모두 그대로다.
>
> **수정 기록 (2026-09-04 ③, AI)** — **v1.5.** `request/ai/turn-index-numbering.md` 회신(✅)에서 백엔드가 확인을 요청한 `occurredAt`의 의미를 **§3-2 필드 표에 명시**했다. 백엔드의 중복 판별 가드(`unique` 위반 시 `occurred_at`으로 재시도와 충돌을 가름)가 이 필드 하나에 걸려 있는데, 계약에는 예시만 있고 규칙이 없었다. **발화 시각 · 밀리초 정밀도 · 재시도 시 동일 값**을 규칙으로 못 박고 §3-2 예시를 초 단위에서 밀리초로 고쳤다(§2-10의 앱 응답 예시는 그대로). **필드 추가·삭제·개명 없음.**
>
> **수정 기록 (2026-09-04 ②, 백엔드)** — **v1.4.** 백엔드 계획 문서를 루트 스펙과 전수 대조하다 나온 공백을 메웠다. ① **§2-8에 `userAvgGap`·`tagGaps` 신설** — 앱 요청 `request/backend/tag-gap-endpoint.md` 회신. spec F9-03의 출력이 어느 엔드포인트에도 없었다 ② **§2-8 `highlights`의 판정 기준을 세션 스냅샷으로 명시** — 임계값은 PRD §14-5로 반드시 한 번 바뀌는데 적용값을 저장하지 않아, 바꾸는 순간 **과거 트렌드의 음영이 소급 변경**된다. `voice_session.gap_threshold` 신설(spec §6-1) ③ **§3-2에 `turnIndex` 채번 규칙 명시** — 이어하기(§2-5-1)가 같은 `sessionId`를 유지하는데 채번 규칙이 없었다. AI가 재연결 후 인덱스를 리셋하면 백엔드의 중복 방어(`unique(session_id, turn_index)`)에 걸려 **이후 턴이 오류 없이 202로 버려진다** ④ **§3-4 응답에 `lastTurnIndex` 추가** — ③의 이어붙임 근거를 서버가 준다 ⑤ §2-5 각주의 "배치 큐 적재"를 실제 방식(`pattern_processed_at`)으로 정정 — 큐는 2026-09-04에 폐기했는데 이 문장만 남아 있었다. **필드 삭제·개명 없음.**
>
> **수정 기록 (2026-09-03 ①, 백엔드)** — 백엔드가 받은 요청 4건(`hume-config-id.md`·`live-turn-signal.md`·`session-context-lookup.md`·`session-summary-endpoint.md`)에 회신하며 **v1.3으로 개정**. 주요 변경 — ① `sessionId` 형식을 `sess_`+짧은 문자열에서 **UUIDv4(접두사 없음)로 교체**(전 예시 일괄 반영, CLM 인증에 쓰이므로 엔트로피 확보) ② `POST /api/session/start`·`resume` 응답에 **`humeConfigId`**(기동 시 fail-fast, null 불가)·**`livePollIntervalSec`** 추가 ③ **§2-13 `GET /api/session/{id}/live` 신설**(폴링, 비데모 계정은 `turns: []`) ④ **§3-4 `GET /internal/sessions/{id}` 신설**(CLM 인증 겸용, 캐시 미스 시 fail-closed) ⑤ **§3-5 `POST /internal/summaries` 신설**(동기 3초, `endReason: timeout`은 미호출) ⑥ §3-2 `/internal/turns` 재시도 1회 → **3회**(전 세션 동일 정책) ⑦ §4 CLM 인증을 `custom_session_id` 검증으로 확정. 상세 결정 근거는 각 요청 문서의 회신(`response/app/`·`response/ai/`) 참조. **이 이후 수정은 이 배너에 번호를 이어 붙인다 (②③…).**

| 항목 | 내용 |
| --- | --- |
| 문서 버전 | v1.9 |
| 작성일 | 2026. 09. 03. (최종 개정 2026. 09. 05.) |
| 상위 문서 | [prd.md](../00-context/prd.md) · [spec.md](../00-context/spec.md) · AI 내부 설계 [ai-pipeline.md](ai-pipeline.md) |
| 범위 | ① 앱 ↔ 백엔드 ② AI서버 ↔ 백엔드(내부) ③ Hume ↔ AI서버(외부·변경 불가) |

> **이 문서는 인터페이스의 단일 출처다.** PRD §8의 엔드포인트 표와 다르면 **이 문서가 우선**한다.
> 필드를 추가·삭제·개명하려면 **먼저 이 문서를 고치고 담당자에게 알린다.** 코드를 먼저 바꾸지 않는다.
> 3인이 병렬로 작업하므로, 이 문서에 적힌 것만 있으면 상대 파트가 완성되지 않아도 각자 진행할 수 있어야 한다.

---

# 1. 공통 규약

## 1-1. 기본

| 항목 | 값 |
| --- | --- |
| Base URL | 백엔드 배포 도메인 (환경변수로 주입, 앱에 하드코딩 금지) |
| 프로토콜 | HTTPS |
| Content-Type | `application/json; charset=utf-8` |
| 인증 | `Authorization: Bearer <JWT>` — `/api/auth/kakao`, `/api/health` 제외 전 엔드포인트 필수 |
| JWT 만료 | **7일.** 매일 쓰는 앱이라 더 짧으면 재로그인이 잦아 이탈 요인이 된다 |
| 시각 | **저장·전송은 UTC ISO 8601** (`2026-09-18T12:34:56Z`) |
| 일자 집계 | **KST(Asia/Seoul) 기준** — 사용자가 체감하는 "하루"가 기준이어야 트렌드가 맞다 |
| 소수 | valence·gap·ratio는 **소수 2자리 반올림**해서 응답한다 |
| `sessionId` | **UUIDv4, 접두사 없음** (예: `550e8400-e29b-41d4-a716-446655440000`). §4 CLM 인증에 `custom_session_id`로 쓰이는 값이라 **로그에 남기지 않는다** — 비밀과 동급으로 취급 |

> **앱 URL 프래그먼트 노출은 허용한다** (v1.7, 2026-09-05 · `request/backend/session-id-in-url.md`). 앱의 대화 상세 경로가 `#/records/{sessionId}`라 이 값이 주소창에 실린다. **로그 금지와 모순되지 않는다** — 근거는 셋이고 백엔드가 실측했다.
> 1. **주소창에 오는 것은 반드시 종료된 세션이다.** `GET /api/sessions`(§2-9)가 `ended_at IS NOT NULL`만 내려준다 — 앱의 관례가 아니라 서버가 보장하는 범위다
> 2. **종료된 세션은 CLM 인증에 쓸 수 없다.** §3-4의 `status: "ended"`를 AI서버가 401로 바꾼다(실측: ended·미존재 401, 열린 세션만 200)
> 3. **종료된 세션은 다시 열리지 않는다.** §2-5-1 이어하기가 `ended_at IS NULL`만 받는다(실측: 404). "지금은 안전한데 나중에 열리는" 경로가 없다
>
> **해시 라우팅이 전제다.** 프래그먼트는 요청 라인·`Referer`에 실리지 않는다. **경로 전략을 path로 바꾸면 이 허용이 무효가 되고** 액세스 로그·`Referer`에 세션 ID가 남는다 — 라우팅을 바꾸려면 이 항목을 같이 봐야 한다.
> **EVI 소켓 URL의 `custom_session_id` 노출은 불가피하다** — §4가 요구하는 값이고, `language_model_api_key`를 앱에 내리지 않는 대신 택한 인증 수단이다.

## 1-2. 오류 응답

모든 오류는 같은 모양이다.

```json
{
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "세션을 찾을 수 없습니다.",
    "traceId": "b17c9f2a"
  }
}
```

| HTTP | code | 발생 |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | 필수 파라미터 누락·형식 오류 |
| 401 | `UNAUTHORIZED` | JWT 없음 |
| 401 | `TOKEN_EXPIRED` | JWT 만료 — 앱은 카카오 재로그인으로 갱신 |
| 401 | `KAKAO_VERIFY_FAILED` | 카카오 액세스 토큰 검증 실패 |
| 401 | `INTERNAL_AUTH_FAILED` | 내부 API 공유 시크릿 불일치 |
| 403 | `FORBIDDEN` | 다른 사용자의 리소스 접근 |
| 404 | `NOT_FOUND` | 리소스 없음 (`SESSION_NOT_FOUND`, `OBSERVATION_NOT_FOUND`) |
| 409 | `SESSION_NOT_RESUMABLE` | 이어하기 창(30분) 경과 또는 잔여 시간 없음 |
| 503 | `HUME_TOKEN_ISSUE_FAILED` | Hume 액세스 토큰 발급 실패 |
| 500 | `INTERNAL_ERROR` | 그 외 |

> **`message`는 사용자에게 그대로 보여도 되는 한국어 문장으로 쓴다.** 앱이 code별 문구를 다시 만들지 않아도 되게 한다. 단 앱이 분기해야 하는 경우엔 **`code`로 분기하고 `message`로 분기하지 않는다.**

## 1-3. null 규칙

계약에서 `null`은 **"측정하지 못했다"**는 뜻이며, 0이나 기본값으로 대체하지 않는다.

| 필드 | null이 되는 경우 | 소비 측 처리 |
| --- | --- | --- |
| `textValence` | 텍스트 valence 분석 호출 실패·타임아웃 (spec F3-06) | 갭 미표시 |
| `voiceValence` | 프로소디 점수 누락, 또는 긍정·부정 합계 질량이 기준(초기 0.05) 미만 — 중립만 찍힌 발화 ([ai-pipeline.md](ai-pipeline.md) §3) | 갭 미표시 |
| `gap` | 위 둘 중 **하나라도** null | 그래프에서 점을 찍지 않는다 |
| `summary` | 요약 생성 실패 | 요약 영역 숨김 |
| `resumedChatGroupId` | 앱이 §2-5-2로 아직 올리지 않은 세션 | **맥락 복원 없이** 이어한다. 이어하기 자체는 정상이다 |
| `observations[]` | 조건 미달로 관찰 미생성 | **빈 배열.** "아직 없어요" 안내만 표시하고 억지 문구를 만들지 않는다 |

**그래프에서 값이 없는 날은 배열에서 아예 생략한다.** 0으로 채우거나 앞뒤를 이어 보간하지 않는다 — 없는 감정을 그리는 것이기 때문이다.

## 1-4. 목록 페이징

| 파라미터 | 기본 | 최대 |
| --- | --- | --- |
| `limit` | 20 | 100 |
| `offset` | 0 | — |

응답에 `total`을 포함한다. 정렬은 **항상 최신순**(`createdAt`/`startedAt` 내림차순)이며 클라이언트가 바꾸지 않는다.

---

# 2. 앱 ↔ 백엔드

## 2-1. `POST /api/auth/kakao` — 로그인

인증 불필요.

**요청**

```json
{
  "kakaoAuthCode": "abcd...",
  "redirectUri": "http://localhost:3000/"
}
```

| 필드 | 규칙 |
| --- | --- |
| `kakaoAuthCode` | 카카오 인가 페이지가 돌려준 **인가 코드**. **1회용이고 10분 만료** — 앱은 사용 후 주소창의 `?code=`를 지운다(안 지우면 새로고침이 같은 코드를 다시 보내 400이 된다) |
| `redirectUri` | **인가 요청에 쓴 것과 정확히 같은 값.** 카카오 토큰 교환이 두 값의 일치를 요구하는데 로컬(`http://localhost:3000/`)과 배포(`https://hackathon-yaho.github.io/emotion/`)가 달라 서버가 하나로 못 박을 수 없다. **서버는 등록된 목록과 대조하고 아니면 400으로 거절한다** — 열어두면 인가 코드를 남의 주소로 흘릴 수 있는 자리다 |

> **웹에서는 액세스 토큰을 앱이 받을 수 없다** (v1.6, 앱이 `kakao_flutter_sdk` 2.0.1 소스로 확인). 웹 빌드에서는 `loginWithKakaoAccount()` 계열이 전부 `notSupported`를 던지고, `authorize()`는 페이지를 리다이렉트한 뒤 빈 문자열을 돌려준다. 그래서 **앱이 하는 일은 인가 URL로 보내는 것까지**이고, 코드를 토큰으로 바꾸는 것은 서버 몫이다.
> **인가 URL의 `client_id`도 REST API 키를 쓴다** — 인가와 교환에서 키가 같아야 한다. 백엔드가 실계정으로 `REST 키 인가 → REST 키 + 시크릿 교환`을 확인했다(2026-09-04).
> **`codeVerifier`(PKCE)는 두지 않는다.** 교환에 서버의 클라이언트 시크릿이 필요해 코드 단독으로는 교환되지 않는다. 넣기로 하면 이 표에 한 칸을 추가한다.

**응답 200**

```json
{
  "jwt": "eyJhbGciOi...",
  "expiresAt": "2026-09-18T12:34:56Z",
  "profileId": "prof_7f3a2b",
  "isNewUser": true
}
```

| 오류 | 조건 |
| --- | --- |
| 400 `VALIDATION_ERROR` | `kakaoAuthCode` 누락 · **`redirectUri`가 등록 목록에 없음** |
| 401 `KAKAO_VERIFY_FAILED` | 코드 교환 실패 — 만료·재사용·`redirect_uri` 불일치 |
| 503 `INTERNAL_ERROR` | 카카오 API 장애 |

> `isNewUser`는 앱이 온보딩 고지(spec F1-05)를 띄울지 판단하는 데만 쓴다.
> 재로그인 시 **동일한 `profileId`**가 반환되어야 한다 (spec TC-01).

## 2-2. `GET /api/me` — 내 정보

**응답 200**

```json
{
  "profileId": "prof_7f3a2b",
  "joinedAt": "2026-09-05T10:00:00Z",
  "sessionCount": 7,
  "thresholdMode": "personal",
  "demoMode": false,
  "openSession": {
    "sessionId": "550e8400-e29b-41d4-a716-446655440000",
    "startedAt": "2026-09-18T12:30:00Z",
    "usedSec": 138,
    "remainingSec": 282,
    "resumableUntil": "2026-09-18T13:03:22Z"
  }
}
```

| 필드 | 설명 |
| --- | --- |
| `openSession` | **비정상 중단으로 열려 있는 세션.** 없으면 `null` |
| `remainingSec` | `hardCutSec − usedSec`. 이어하기해도 **원가 상한이 유지되도록** 남은 시간만 준다 |
| `resumableUntil` | 이 시각을 넘기면 스케줄러가 자동 종료한다 (중단 후 30분) |

> 홈(S01)과 설정(S06)이 공용으로 쓴다. `thresholdMode`는 표시용이며, 실제 적용 값은 세션 시작 시점에 다시 내려온다(2-4).
> 앱은 `openSession != null`이면 홈에서 **"이어서 이야기할까요?"**를 제안한다 (spec F2-07).

## 2-3. `DELETE /api/account` — 탈퇴

**요청 본문 (선택, v1.6)**

```json
{
  "kakaoAuthCode": "abcd...",
  "redirectUri": "http://localhost:3000/"
}
```

**응답 204** (본문 없음)

| 오류 | 조건 |
| --- | --- |
| 500 `INTERNAL_ERROR` | 삭제 트랜잭션 실패 — **부분 삭제 상태를 남기지 않고 롤백** |

> 삭제 대상 10개 테이블은 spec F10-03 참조. 유예 기간을 두지 않는다.
> **본문은 카카오 연결 해제(unlink)용이며 선택이다** (v1.6). 있으면 백엔드가 **데이터를 지운 뒤** 그 코드로 받은 사용자 토큰으로 `POST /v1/user/unlink`를 호출한다. 없으면 데이터만 지우고 **똑같이 204**를 준다 — unlink 실패는 오류로 올리지 않는다(우리 데이터는 이미 없다).
> **앱은 탈퇴 버튼을 누른 시점에 카카오 인가를 한 번 더 통과시켜 코드를 얻는다.** 이미 동의한 계정이면 동의 화면 없이 되돌아오는 것이 보통이다.
> **왜 토큰을 보관하지 않는가** — 로그인 때 받는 액세스 토큰은 6시간, 리프레시 토큰은 2개월이다. 탈퇴 시점까지 쓰려면 리프레시 토큰을 저장해야 하는데, 그러면 **모든 사용자의 2개월짜리 카카오 자격증명을 우리 DB가 들고 있게 된다.** "저장하는 것은 회원번호 하나"라는 제품 주장(PRD §5.1·F10-04)과 정면으로 어긋난다.
> **어드민 키는 쓰지 않는다.** `unlink`는 사용자 액세스 토큰(Bearer)으로 동작하며, 어드민 키 방식은 `target_id`로 남을 끊을 때 쓰는 경로다.

## 2-4. `POST /api/session/start` — 대화 세션 시작

**요청**: 본문 없음

**응답 201**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "humeAccessToken": "hume_at_...",
  "humeTokenExpiresAt": "2026-09-18T12:44:56Z",
  "humeConfigId": "cfg_8a12ff",
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "softWrapSec": 300,
  "hardCutSec": 420,
  "livePollIntervalSec": 2,
  "demoMode": false
}
```

| 필드 | 설명 |
| --- | --- |
| `humeAccessToken` | **단기 토큰.** Hume API 키는 절대 내려보내지 않는다 (spec TC-03) |
| `humeConfigId` | **v1.3 신설.** EVI handshake의 `config_id` 쿼리에 그대로 전달한다(저장하지 않는다). Hume 콘솔 Config는 AI서버가 생성·소유하고 CLM 엔드포인트를 등록한다 — 백엔드는 환경변수로 전달만 한다. **null 불가** — 값은 백엔드 기동 시 환경변수에서 읽고, 없으면 서버가 기동하지 않는다(런타임 실패가 아니라 배포 설정 오류) |
| `thresholdMode` | `"fixed"` (세션 5회 미만) / `"personal"` (5회 이상) |
| `gapThreshold` | 이번 세션에 적용되는 실제 임계값. 앱은 표시하지 않고 **데모 모드에서만** 참고. **예시의 `0.85`는 확정값이 아니다** — 초기 수치는 20쌍 세트 측정 후 결정(PRD §14-5) |
| `softWrapSec` · `hardCutSec` | 300 / 420 고정. **서버가 내려주는 값을 쓰고 앱에 상수로 박지 않는다** — 정책 변경 시 배포 없이 바꾸기 위함 |
| `livePollIntervalSec` | **v1.3 신설.** §2-13 폴링 간격(초). `softWrapSec`과 같은 이유로 서버가 내려주고 앱은 상수로 박지 않는다 |

| 오류 | 조건 |
| --- | --- |
| 503 `HUME_TOKEN_ISSUE_FAILED` | Hume 토큰 발급 실패 → 앱은 대화 시작을 **차단**하고 안내 |

## 2-5. `POST /api/session/{sessionId}/end` — 세션 종료

**요청**

```json
{ "endReason": "user_end" }
```

`endReason`: `"user_end"` | `"soft_wrap"` | `"hard_cut"` | `"timeout"`(스케줄러 전용) | `"resumed"`(이어하기로 승계됨)

> 앱은 `timeout`·`resumed`를 보내지 않는다. 서버 내부에서만 기록한다.

**응답 200**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "durationSec": 214,
  "turnCount": 12,
  "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
  "gapAvg": 0.94
}
```

| 오류 | 조건 |
| --- | --- |
| 404 `SESSION_NOT_FOUND` | — |
| 403 `FORBIDDEN` | 타 사용자 세션 |

> 종료 처리는 **그 세션을 패턴 분석 배치의 미처리 상태로 남긴다**(spec F7-01) — `ended_at`이 기록되고 `pattern_processed_at`이 NULL인 것 자체가 미처리이며, 별도 큐에 넣지 않는다(2026-09-04 확정). 배치는 비동기이므로 이 응답에 관찰이 포함되지 않는다.
> **`summary`는 null일 수 있다**(생성 실패). 대화 기록 자체는 남는다.
> **요약 생성 (v1.3)** — `endReason`이 `user_end`·`soft_wrap`·`hard_cut`이면 백엔드가 §3-5 `POST /internal/summaries`를 **동기 호출**(타임아웃 3초)해 `summary`를 채운다. 실패·타임아웃이면 `null`. **`endReason: "timeout"`(F2-06 스케줄러)은 이 호출을 하지 않고 항상 `summary: null`** — 미종료 세션을 여러 건 정리할 때 건당 3초씩 대기하지 않기 위함이며, 어차피 아무도 보고 있지 않은 세션이다.

## 2-5-1. `POST /api/session/{sessionId}/resume` — 중단 세션 이어하기 (P1)

`GET /api/me`의 `openSession`이 있을 때만 호출한다.

**응답 200**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "humeAccessToken": "hume_at_...",
  "humeTokenExpiresAt": "2026-09-18T13:05:00Z",
  "humeConfigId": "cfg_8a12ff",
  "resumedChatGroupId": "cg_2b7f11",
  "remainingSec": 282,
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "demoMode": false
}
```

| 필드 | 설명 |
| --- | --- |
| `humeConfigId` | **v1.3 신설.** §2-4와 동일 값 — 재연결도 같은 Config로 붙어야 CLM이 이어진다 |
| `resumedChatGroupId` | 앱이 EVI 핸드셰이크의 `resumed_chat_group_id` 쿼리 파라미터로 넘긴다. **이전 대화 맥락이 복원된다** — [Resuming Chats](https://dev.hume.ai/docs/speech-to-speech-evi/features/resume-chats). **§2-5-2로 값을 받지 못한 세션은 `null`이다 — 빈 문자열은 오지 않는다**(v1.8) |
| `remainingSec` | `hardCutSec − usedSec`. **새 7분을 주지 않는다** — 이어하기로 원가 상한이 뚫리면 안 된다 (PRD NFR-06) |

| 오류 | 조건 |
| --- | --- |
| 404 `SESSION_NOT_FOUND` | 이미 종료·정리된 세션 |
| 409 `SESSION_NOT_RESUMABLE` | `resumableUntil` 경과 또는 `remainingSec <= 0` |

> **이어하기 창은 중단 후 30분이다.** 하드컷이 7분이라 정상 세션은 걸리지 않고, 감정 대화에서 몇 시간 뒤에 잇는 것은 이미 다른 대화이기 때문이다.
> 사용자가 "아니오"를 고르면 앱은 이 대신 `POST /api/session/{id}/end`(`endReason: "user_end"`)를 호출해 그 세션을 닫는다.

## 2-5-2. `POST /api/session/{sessionId}/chat-group` — 대화 그룹 ID 보관 (v1.8 신설)

앱이 EVI 소켓을 연 직후 `chat_metadata`로 받는 `chat_group_id`를 **받자마자 한 번** 올린다. 이 값이 없으면 §2-5-1의 `resumedChatGroupId`가 항상 `null`이라 **이어하기는 되지만 이전 대화 맥락이 복원되지 않는다.**

**요청**

```json
POST /api/session/550e8400-e29b-41d4-a716-446655440000/chat-group
{ "chatGroupId": "cg_2b7f11" }
```

**응답 204** — 본문 없음.

| 필드 | 규칙 |
| --- | --- |
| `chatGroupId` | **필수.** 공백 불가, 200자 이하. Hume이 준 문자열을 **그대로** 올린다 — 백엔드는 형식을 검사하지 않는다(접두사가 바뀌어도 우리가 먼저 깨지지 않게) |

| 오류 | 조건 |
| --- | --- |
| 400 `VALIDATION_ERROR` | `chatGroupId`가 없거나 공백뿐 |
| 403 `FORBIDDEN` | 남의 세션 |
| 404 `SESSION_NOT_FOUND` | 없는 세션 |

> **멱등하다.** 같은 값을 몇 번 보내도 204이고, **다른 값이 오면 마지막 값이 이긴다** — 값이 바뀌었다는 것은 새 그룹이 생겼다는 뜻이라 이전 그룹에는 이어붙일 맥락이 없다. 앱은 재연결마다 그냥 보내면 된다.
>
> **종료된 세션에도 204다.** 소켓 직후에 보내는 값이라 도착 전에 세션이 닫힐 수 있는데, 그걸 404로 튕기면 앱이 재시도해도 영영 성공하지 못한다. 저장은 해롭지 않다.
>
> **`end`(§2-5) 본문으로 받지 않는 이유** — 앱이 강제 종료되면 `end` 호출 자체가 없다. **그런데 이어하기가 필요한 상황이 정확히 그 상황이다.**

## 2-6. `GET /api/observations` — 관찰 목록

**쿼리**: `limit`, `offset`

**응답 200**

```json
{
  "total": 3,
  "observations": [
    {
      "observationId": "obs_014",
      "createdAt": "2026-09-18T09:00:00Z",
      "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.",
      "evidence": {
        "tag": "회의",
        "occurrences": 7,
        "tagAvgGap": 1.31,
        "userAvgGap": 0.72,
        "ratio": 1.82
      },
      "feedback": null
    }
  ]
}
```

`feedback`: `"agree"` | `"disagree"` | `null`(미응답)

> **`evidence`는 목록에서도 반드시 함께 내려간다.** 관찰 문장만 있고 근거가 없는 상태를 계약 수준에서 만들지 않기 위함이다 (PRD FR-053).
> 관찰이 없으면 `observations: []`, `total: 0`. 앱은 안내 문구만 띄우고 **가짜 관찰을 만들지 않는다.**

## 2-7. `GET /api/observations/{observationId}/evidence` — 관찰 근거

**응답 200**

```json
{
  "observationId": "obs_014",
  "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.",
  "evidence": {
    "tag": "회의",
    "occurrences": 7,
    "tagAvgGap": 1.31,
    "userAvgGap": 0.72,
    "ratio": 1.82
  },
  "turns": [
    {
      "turnId": "turn_0031",
      "sessionId": "550e8400-e29b-41d4-a716-446655440000",
      "occurredAt": "2026-09-12T13:20:11Z",
      "transcript": "오늘 회의가 세 개나 있었는데 다 괜찮았어요",
      "textValence": 0.62,
      "voiceValence": -0.58,
      "gap": 1.20
    }
  ]
}
```

| 오류 | 조건 |
| --- | --- |
| 404 `OBSERVATION_NOT_FOUND` | 근거 대화가 삭제되어 관찰이 무효화된 경우 포함 (spec F10-02) |

> **`turns` 길이는 `evidence.occurrences`와 반드시 같다.** 다르면 계약 위반이며 PRD §1.4의 "evidence 불일치 0건" 지표 실패로 집계한다.

## 2-7-1. `POST /api/observations/{observationId}/feedback` — 관찰 피드백 (P1)

**요청**

```json
{ "feedback": "disagree" }
```

`feedback`: `"agree"` | `"disagree"` — 관찰당 **1회**. 재호출 시 덮어쓴다.

**응답 200**

```json
{ "observationId": "obs_014", "feedback": "disagree" }
```

> **`disagree`는 관찰을 삭제하지 않는다.** 표시만 남긴다 — 사용자가 부정했다고 우리가 계산한 숫자가 틀린 것은 아니고, evidence는 그대로 유효하다. 삭제하면 PRD §1.4의 "evidence 불일치 0건" 판정 대상이 사라져 지표가 왜곡된다.
> 이유 입력·취소는 제공하지 않는다. 붙는 순간 P1 범위를 벗어난다.

## 2-8. `GET /api/trend` — 감정 추세 (두 선 그래프)

**쿼리**: `range` = `7d` | `30d` | `90d` (기본 `30d`)

**응답 200**

```json
{
  "range": "30d",
  "timezone": "Asia/Seoul",
  "points": [
    { "date": "2026-09-12", "textValence": 0.61, "voiceValence": -0.42, "gap": 1.03, "sessionCount": 1 },
    { "date": "2026-09-14", "textValence": 0.20, "voiceValence": 0.11, "gap": 0.09, "sessionCount": 2 }
  ],
  "highlights": [
    { "from": "2026-09-11", "to": "2026-09-13", "reason": "gap_exceeded" }
  ],
  "userAvgGap": 0.72,
  "tagGaps": [
    { "tag": "회의", "occurrences": 7, "tagAvgGap": 1.31 },
    { "tag": "야근", "occurrences": 4, "tagAvgGap": 0.98 },
    { "tag": "가족", "occurrences": 3, "tagAvgGap": 0.65 }
  ]
}
```

| 규칙 | 내용 |
| --- | --- |
| 없는 날 | `points`에서 **생략**한다. 0으로 채우거나 보간하지 않는다 |
| 값 범위 | `textValence`·`voiceValence`는 −1.00 ~ 1.00 |
| 하루에 2세션 이상 | 그날의 **평균**. `sessionCount`로 표시 |
| `highlights` | 갭이 임계를 넘은 **연속 구간**. 앱은 이 구간을 음영 처리하고, 탭하면 해당 날짜의 대화 상세로 이동 (spec F9-02) |
| `highlights` 판정 기준 (**v1.4**) | 그날의 세션에 **실제로 적용됐던 임계값**(`voice_session.gap_threshold` 스냅샷, spec §6-1)과 비교한다. 현재 설정값과 비교하지 않는다 — 아래 주의 |
| `userAvgGap` (**v1.4**) | 그 사용자 **전 기간** 평균 갭. `tagGaps` 막대의 기준선이며, 앱은 이 값에 ×1.5를 곱해 판정선을 그린다. 갭이 `null`인 턴은 제외 |
| `tagGaps` (**v1.4**) | `range`에 **종속**된다. **등장 3회 이상만 서버가 걸러** 내려주고(F7-03과 같은 기준), `tagAvgGap` **내림차순**, **상위 7개**까지. 조건을 만족하는 태그가 없으면 `[]` |

> **`highlights`는 F9-02, `tagGaps`는 F9-03(P1)이다.** 둘 다 `GET /api/trend` 한 번에 실려 오므로 S04는 호출이 늘지 않는다.
> **`tagGaps`가 관찰(§2-6)로 대체되지 않는 이유** — 관찰은 판정을 **통과한** 태그만 만들어진다(3회 이상 AND 1.5배 이상). S04 막대 차트의 값은 "3회 이상이지만 1.5배 **미만**인 태그"를 함께 보여주는 데 있다. 넘은 것만 보이면 비교 대상이 없어 "왜 이게 발견인가"가 설명되지 않는다.
> **`highlights`가 현재 임계값을 쓰지 않는 이유 (v1.4)** — 초기 임계값은 20쌍 세트 측정 후 확정된다(PRD §14-5). 현재값으로 소급 판정하면 **임계값을 바꾸는 순간 과거 날짜의 음영이 통째로 달라지고**, 그날 앱이 실제로 되물었던 근거(FR-022)와 화면이 어긋난다. 세션 시작 시 적용값을 그대로 스냅샷해 두고 그것으로 판정한다.

## 2-9. `GET /api/sessions` — 대화 기록 목록

**쿼리**: `limit`, `offset`

**응답 200**

```json
{
  "total": 12,
  "sessions": [
    {
      "sessionId": "550e8400-e29b-41d4-a716-446655440000",
      "startedAt": "2026-09-18T12:30:00Z",
      "durationSec": 214,
      "turnCount": 12,
      "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
      "gapAvg": 0.94,
      "tags": ["회의", "야근"]
    }
  ]
}
```

`tags`는 그 세션에서 가장 많이 등장한 상위 3개까지.

## 2-10. `GET /api/sessions/{sessionId}` — 대화 상세

**응답 200**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "startedAt": "2026-09-18T12:30:00Z",
  "endedAt": "2026-09-18T12:33:34Z",
  "durationSec": 214,
  "endReason": "user_end",
  "thresholdMode": "fixed",
  "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
  "turns": [
    {
      "turnId": "turn_0031",
      "turnIndex": 3,
      "occurredAt": "2026-09-18T12:31:02Z",
      "role": "user",
      "transcript": "오늘 완전 괜찮았어요",
      "textValence": 0.70,
      "voiceValence": -0.62,
      "gap": 1.32,
      "gapTriggered": true,
      "tags": ["회의"]
    },
    {
      "turnId": "turn_0032",
      "turnIndex": 4,
      "occurredAt": "2026-09-18T12:31:06Z",
      "role": "assistant",
      "transcript": "괜찮다고 하시는데 목소리는 좀 다르네요. 무슨 일 있으셨어요?",
      "textValence": null,
      "voiceValence": null,
      "gap": null,
      "gapTriggered": false,
      "tags": []
    }
  ]
}
```

> **assistant 턴은 valence·gap이 전부 `null`이다.** 측정 대상은 사용자 발화뿐이다.
> 갭 수치는 **이 화면에서는 노출된다.** 대화 중 화면(S02)과 구분되는 지점이다 (PRD FR-031).

## 2-11. `DELETE /api/sessions/{sessionId}` — 대화 삭제

**응답 200**

```json
{
  "deletedSessionId": "550e8400-e29b-41d4-a716-446655440000",
  "deletedTurnCount": 12,
  "removedObservationIds": ["obs_014"],
  "recalculatedObservationIds": ["obs_009"]
}
```

| 필드 | 의미 |
| --- | --- |
| `removedObservationIds` | 남은 근거가 3회 미만이 되어 **삭제된** 관찰 |
| `recalculatedObservationIds` | 근거는 남았으나 **숫자가 재계산된** 관찰 |

> 앱은 이 응답을 받으면 관찰 목록 캐시를 무효화한다. 근거를 잃은 관찰이 화면에 남아 있으면 그 순간 "근거 없는 문장"이 된다 (PRD FR-081).
> 이 호출은 `user_baseline` 재계산도 함께 수행한다 (spec F3-05).

## 2-12. `GET /api/health` — 헬스체크

인증 불필요.

**응답 200**

```json
{ "status": "ok", "db": "ok", "timestamp": "2026-09-18T12:34:56Z" }
```

DB 연결 확인을 포함한다. **Supabase 유휴 일시정지 방지용 주기 호출**에도 사용한다.

## 2-13. `GET /api/session/{sessionId}/live` — 대화 중 턴 신호 (v1.3 신설)

**S02 화면에서만 호출한다.** 대화 종료·화면 이탈 시 폴링을 멈춘다. 간격은 §2-4 `livePollIntervalSec`를 따른다.

**쿼리**: `sinceTurnIndex` (마지막으로 받은 `turnIndex`. 생략 시 세션 시작부터)

**응답 200**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "lastTurnIndex": 7,
  "crisisDetected": true,
  "turns": [
    { "turnIndex": 7, "textValence": 0.70, "voiceValence": -0.62, "gap": 1.32, "gapTriggered": true }
  ]
}
```

| 필드 | 규칙 |
| --- | --- |
| `crisisDetected` | **세션 단위 boolean.** turn 단위로 묶지 않는다 — `crisis_event`에 `turn_id`를 두지 않은 것과 같은 이유(§6-1). 앱은 `false → true` 전이에서 **한 번만** S07을 띄운다 |
| `turns` | `demoMode == true`일 때만 채운다. **`demoMode == false`면 항상 `turns: []`** — `crisisDetected`는 이 경우에도 정상 값을 내려준다. §1-3의 `null`(측정 못함)과 뜻이 섞이지 않도록 **`null`로 마스킹하지 않는다** |
| `transcript` | **포함하지 않는다.** 앱은 EVI에서 이미 텍스트를 받고 있어 불필요하고, 노출면만 늘어난다 |
| 소스 | `/internal/turns`(§3-2)로 이미 받은 값을 그대로 되돌려준다 — 새 계산·새 저장 없음 |

| 오류 | 조건 |
| --- | --- |
| 404 `SESSION_NOT_FOUND` | — |
| 403 `FORBIDDEN` | 타 사용자 세션 |

---

## 2-14. 대화 대기열 (v1.9 신설)

Hume의 **동시 접속 상한**에 걸린 사용자를 줄 세운다. **Hume은 대기를 지원하지 않는다** — 상한을 넘긴 연결은 `E0700`("too many active chats")으로 **즉시 거절**되므로, 순번·대기 시간은 전부 이 서버가 만든다.

> **기본은 꺼져 있다**(`SESSION_QUEUE_ENABLED`). 꺼진 상태에서는 §2-4가 202를 내지 않고 이 절의 엔드포인트를 쓸 일이 없다 — **동작이 v1.8과 같다.**

### 정원이 찼을 때 — §2-4가 202를 낸다

```json
POST /api/session/start
→ 202 Accepted
{
  "ticketId": "b2f4c1a0-1d3e-4f56-9a7b-8c9d0e1f2a3b",
  "position": 3,
  "pollIntervalSec": 2,
  "session": null
}
```

### `GET /api/session/queue/{ticketId}` — 순번 폴링

`pollIntervalSec` 간격으로 부른다. **`position`이 0이면 `session`에 §2-4와 같은 모양의 응답이 실려 있고, 그것이 입장권이다.**

```json
→ 200 { "ticketId": "b2f4…", "position": 1, "pollIntervalSec": 2, "session": null }
→ 200 { "ticketId": "b2f4…", "position": 0, "pollIntervalSec": 2,
        "session": { "sessionId": "…", "humeAccessToken": "…", "humeConfigId": "…", … } }
```

| 필드 | 설명 |
| --- | --- |
| `position` | **1부터 센다.** 내 앞에 몇 명이 아니라 **내가 몇 번째**다. `0`은 "입장했다"는 뜻이며 이때만 `session`이 채워진다 |
| `session` | `position > 0`이면 항상 `null`. **자리를 미리 잡아 두지 않는다** — 예약이 없으니 만료 타이머도, 남이 가로챌 자리도 없다 |

| 오류 | 조건 |
| --- | --- |
| 404 `QUEUE_TICKET_NOT_FOUND` | 없는 티켓 · **폴링이 끊겨 만료된 티켓** · **남의 티켓** |

> **폴링을 멈추면 티켓이 만료된다.** 브라우저를 닫은 사람이 줄을 영원히 막기 때문이다. 만료 뒤에는 §2-4부터 다시 시작한다.
>
> **남의 티켓은 404다**(403이 아니다). 그 응답이 곧 세션과 토큰이라 존재 여부조차 알려주지 않는다.
>
> **한 사람에게 티켓 하나다.** 대기 중에 §2-4를 다시 불러도 **같은 `ticketId`와 같은 순번**이 온다 — 새로 고침으로 줄이 늘거나 앞당겨지지 않는다.

### `DELETE /api/session/queue/{ticketId}` — 기다리기 그만두기

**204.** 없는 티켓이어도 204다.

### 서버가 정원을 세는 방법 (앱은 몰라도 된다)

Hume의 `GET /v0/evi/chats?status=ACTIVE`를 본다. **`voice_session`의 열린 행을 세지 않는다** — Hume은 **비활성 2분**이면 채팅을 닫는데 우리 세션은 **30분**을 열어 두므로(§2-2 `resumableUntil`), 우리 행을 세면 **실제로 비어 있는 자리를 두고 사람을 돌려보낸다.**

- **줄 맨 앞의 폴링에서만** 조회한다 — 대기자가 늘어도 Hume 호출은 `pollIntervalSec`당 한 번이다
- **조회에 실패하면 입장시킨다(fail-open).** 조회가 죽었다고 대화를 막지 않는다 — 정원을 넘겨 붙으면 Hume이 `E0700`으로 거절하고 **앱이 그 오류를 §2-4부터 다시 태운다**

# 3. AI서버 → 백엔드 (내부)

## 3-1. 인증

| 항목 | 값 |
| --- | --- |
| 헤더 | `X-Internal-Secret: <공유 시크릿>` |
| 실패 | 401 `INTERNAL_AUTH_FAILED` |

시크릿은 양쪽 환경변수로만 주입한다. 리포지토리에 넣지 않는다.

## 3-2. `POST /internal/turns` — 턴 로그 적재

**요청**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "turnIndex": 3,
  "role": "user",
  "occurredAt": "2026-09-18T12:31:02.417Z",
  "transcript": "오늘 완전 괜찮았어요",
  "textValence": 0.70,
  "voiceValence": -0.62,
  "gap": 1.32,
  "gapTriggered": true,
  "thresholdMode": "fixed",
  "tags": ["회의"],
  "topProsody": { "Tiredness": 0.71, "Sadness": 0.42, "Joy": 0.06 },
  "crisis": { "detected": false, "by": null }
}
```

| 필드 | 규칙 |
| --- | --- |
| `turnIndex` | **세션 내에서 단조 증가하는 정수.** AI서버가 채번한다. **이어하기(§2-5-1)로 재연결해도 `sessionId`가 같으므로 인덱스를 0부터 다시 시작하지 않고 직전 값에서 이어 붙인다** — 재연결 직후의 시작점은 §3-4 응답의 `lastTurnIndex`로 확인한다 (v1.4) |
| `occurredAt` | **발화 시각.** RFC 3339, **밀리초 정밀도**(`2026-09-18T12:31:02.417Z`). 적재 시각·전송 시각이 아니다. **재시도는 최초 시도와 완전히 같은 값을 보낸다** — 백엔드가 `unique (session_id, turn_index)` 충돌을 "재시도"와 "다른 발화"로 가르는 기준이 이 필드다. 같은 세션의 서로 다른 발화가 같은 값을 갖지 않는다. AI서버의 UTC 시계로 찍으므로 실제 발성보다 수백 ms 뒤다 (v1.5) |
| `role` | `"user"` \| `"assistant"`. assistant 턴은 valence·gap·tags가 전부 null/빈 배열 |
| `tags` | **원문 대조 검증을 통과한 태그만** 보낸다 (spec F6-02). 백엔드는 재검증하지 않는다 |
| `topProsody` | 상위 5개까지. 디버깅·재현성 검증용 |
| `crisis.by` | `"rule"` \| `"llm"` \| `null` |
| **음성 원본** | **필드 자체가 없다.** 어떤 형태로도 전송하지 않는다 (PRD FR-041) |

**응답 202** (본문 없음)

| 오류 | AI서버 동작 |
| --- | --- |
| 4xx | 재시도하지 않는다. `ops_error_log` 적재 후 진행 |
| 5xx · 타임아웃 | **3회 재시도**(백오프) 후 포기 — v1.3, 기존 1회에서 상향. **모든 세션에 동일하게 적용**(데모 계정 전용 분기를 두지 않는다) |

> **이 호출은 fire-and-forget이다.** 실패해도 대화 응답을 막지 않는다 (spec F5-04). 백엔드가 내려가 있어도 사용자는 대화를 계속할 수 있어야 한다.
> **`turnIndex` 중복은 오류가 아니라 "이미 적재됨"으로 처리된다 (202).** 3회 재시도가 있어 같은 턴이 실제로 두 번 도착하기 때문이다. **그래서 채번 규칙이 지켜지지 않으면 유실이 조용하다** — 이어하기 후 인덱스를 리셋하면 이후의 모든 새 턴이 "중복"으로 판정돼 오류 없이 버려진다 (v1.4).

## 3-3. `POST /internal/observations` — 관찰 문장 반환 (배치)

백엔드가 집계·판정을 마친 뒤 AI서버에 문장화를 요청하고, 그 결과를 저장하는 경로.

**백엔드 → AI서버 요청**

```json
{
  "tag": "회의",
  "occurrences": 7,
  "tagAvgGap": 1.31,
  "userAvgGap": 0.72,
  "ratio": 1.82
}
```

**AI서버 응답 200**

```json
{ "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요." }
```

| 규칙 | 내용 |
| --- | --- |
| 입력 | **숫자와 태그만.** 원본 대화를 보내지 않는다 |
| 출력 | 한 문장. **주어진 숫자를 바꾸거나 없는 사실을 추가하지 않는다** (PRD §9.3 조항 7) |
| 실패 | 관찰을 생성하지 않는다. **템플릿 문장으로 대체하지 않는다** — 표현이 어색한 것보다 근거 없는 문장이 나가는 쪽이 위험하다 |

## 3-4. `GET /internal/sessions/{sessionId}` — 세션 컨텍스트 조회 (v1.3 신설)

AI서버 → 백엔드. **CLM 인증을 겸한다** — §4 참조.

**요청**: 헤더 `X-Internal-Secret`

**응답 200**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "open",
  "startedAt": "2026-09-18T12:30:00Z",
  "usedSec": 0,
  "lastTurnIndex": 0,
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "softWrapSec": 300,
  "hardCutSec": 420,
  "demoMode": false,
  "recentObservations": [
    { "observationId": "obs_014", "tag": "회의", "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요." }
  ]
}
```

| 필드 | 규칙 |
| --- | --- |
| `status` | `"open"` \| `"ended"` |
| `usedSec` | 이어하기(§2-5-1) 세션이면 이미 쓴 시간. `startedAt`과 함께 5분 마무리 유도(spec F2-03) 판단에 쓴다 |
| `lastTurnIndex` (**v1.4**) | 그 세션에 **지금까지 적재된 최대 `turnIndex`.** 적재된 턴이 없으면 `0`. AI서버는 §3-2 채번을 이 값 다음부터 이어 붙인다 — 이어하기로 재연결했을 때 인덱스를 리셋하지 않기 위한 근거다 |
| `recentObservations` | 최근 3개. F8(P1, 관찰 근거 기반 제안)에서 사용 |
| `transcript`류 | **포함하지 않는다** |

| 오류 | 조건 |
| --- | --- |
| 404 | 없는 `sessionId` |
| — | `status: "ended"`도 200으로 반환한다. **401로 바꾸는 것은 AI서버의 몫**이다(§4) |

> **호출 빈도는 세션당 1회.** AI서버가 `hardCutSec + 30분` TTL로 캐시한다 — 실시간 경로(Hume → AI서버)에 매 턴 홉을 더하지 않기 위함이다.
> **조회 실패(캐시 미스 + 5xx·타임아웃) 시 AI서버는 fail-closed로 401을 Hume에 돌려준다.** 백엔드가 죽어 있으면 `POST /api/session/start`도 죽어 있어 애초에 새 세션이 생기지 않으므로, fail-closed로 잃는 가용성이 없다. 이미 검증된 세션은 캐시가 지킨다.

## 3-5. `POST /internal/summaries` — 세션 요약 생성 (v1.3 신설)

백엔드 → AI서버. §2-5 참조 — `endReason`이 `timeout`이 아닐 때만, **동기 호출·타임아웃 3초**.

**백엔드 → AI서버 요청**

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "turns": [
    { "role": "user", "transcript": "오늘 회의가 세 개나 있었는데 다 괜찮았어요" },
    { "role": "assistant", "transcript": "괜찮다고 하시는데 목소리는 좀 다르네요. 무슨 일 있으셨어요?" }
  ]
}
```

**AI서버 응답 200**

```json
{ "summary": "회의가 많았던 하루에 대해 이야기했습니다." }
```

| 규칙 | 내용 |
| --- | --- |
| 입력 | 턴 텍스트만. valence·갭·태그는 보내지 않는다 — 요약에 수치가 섞이면 S02-1이 갭을 노출하는 셈이 된다(FR-031 취지) |
| 출력 | 한 문장, 존댓말, **감정 단정 없음**("힘든 하루였네요" 금지). 진단·조언 없음 |
| 실패 | AI서버가 `422 SUMMARY_REJECTED`(사후 검사 실패) 또는 5xx. 백엔드는 **재시도하지 않고** `summary: null`로 §2-5 응답 |

---

# 4. Hume ↔ AI서버 (외부 계약 · 변경 불가)

우리가 정의하는 계약이 아니라 **Hume이 정한 규격**이다. 맞추는 쪽은 우리다.

| 항목 | 값 |
| --- | --- |
| 엔드포인트 | `POST /chat/completions?custom_session_id={sessionId}` |
| 인증 | `Authorization: Bearer <api_key>` |
| 요청 | `messages[]` — `role`, `content`, `time{begin,end}`, `models.prosody.scores{48종}` |
| 응답 | **SSE.** `Content-Type: text/event-stream`, OpenAI `ChatCompletionChunk` 청크 스트리밍 후 `data: [DONE]` |
| 세션 식별 | 응답 청크의 `system_fingerprint`에 세션 ID 반영 |

**요청 예시**

```json
{
  "messages": [
    {
      "role": "user",
      "content": "오늘 완전 괜찮았어요",
      "time": { "begin": 12400, "end": 14100 },
      "models": { "prosody": { "scores": { "Tiredness": 0.71, "Sadness": 0.42, "Joy": 0.06 } } }
    }
  ],
  "model": "our-clm"
}
```

**응답 예시**

```
data: {"choices":[{"delta":{"content":"괜찮다고 하시는데 "}}],"system_fingerprint":"550e8400-e29b-41d4-a716-446655440000"}

data: {"choices":[{"delta":{"content":"목소리는 좀 다르네요. 무슨 일 있으셨어요?"}}]}

data: [DONE]
```

> **이 스트림에는 대화 텍스트만 실린다.** 텍스트 valence·태그·위기 판정은 응답 호출과 분리된 분석 호출에서 나오므로(spec F3-02, v1.2), 스트림에 메타 태그·JSON이 섞일 경로 자체가 없다. 섞여 나오면 즉시 결함이다 — 사용자에게 음성으로 읽힌다.
> **CLM 인증 (v1.3 확정)**: `language_model_api_key`는 앱이 `session_settings`로 보내야 해서 웹 번들에 노출된다 — **미사용.** 대신 AI서버가 §3-4 `GET /internal/sessions/{sessionId}`로 `custom_session_id`를 검증한다. 모르는 ID·`ended` 상태·조회 실패(캐시 미스 시)는 전부 **AI서버가 Hume에 401**을 돌려준다. 세션당 1회 조회 후 `hardCutSec + 30분` TTL로 캐시한다.

출처: [Hume Custom Language Model 가이드](https://dev.hume.ai/docs/speech-to-speech-evi/guides/custom-language-model)

---

# 5. 화면 ↔ 엔드포인트 매핑

| 화면 | 호출 |
| --- | --- |
| S00 진입·로그인 | `POST /api/auth/kakao` |
| S01 홈 | `GET /api/me`(`openSession` 포함), `GET /api/observations?limit=3` |
| S02 대화 | `POST /api/session/start`(**정원이 차면 202 → §2-14 대기 화면 → 폴링 응답의 `session`으로 이어서**, v1.9) **또는** `POST /api/session/{id}/resume` → (Hume 직접 연결) → **`POST /api/session/{id}/chat-group`**(소켓 직후 1회, §2-5-2, v1.8) → **`GET /api/session/{id}/live` 폴링(§2-13, v1.3)** → `POST /api/session/{id}/end` |
| S02-1 종료 요약 | 2-5 응답 재사용 (추가 호출 없음) |
| S03 발견 | `GET /api/observations`, `POST /api/observations/{id}/feedback` |
| S03-1 관찰 근거 | `GET /api/observations/{id}/evidence` |
| S04 트렌드 | `GET /api/trend?range=30d` |
| S05 기록 | `GET /api/sessions` |
| S05-1 대화 상세 | `GET /api/sessions/{id}`, `DELETE /api/sessions/{id}` |
| S06 설정 | `GET /api/me`, `DELETE /api/account` |
| S07 위기 안내 | **`GET /api/session/{id}/live`의 `crisisDetected`(§2-13, v1.3)** — `false → true` 전이에서 1회 표시. 적재는 AI서버가 `/internal/turns`의 `crisis`로 처리 |

---

# 6. 변경 절차

1. 이 문서를 먼저 고치고 **버전을 올린다**
2. 변경 이력에 **무엇을 왜 바꿨는지** 적는다
3. 영향받는 담당자에게 알린다 (앱 / 백엔드 / AI)
4. 그 다음에 코드를 바꾼다

**필드 삭제·개명은 특히 주의한다.** 3인이 병렬로 가는 동안 상대는 이 문서만 보고 만들고 있다.

## 변경 이력

| 버전 | 일자 | 내용 |
| --- | --- | --- |
| **v1.9** | **2026-09-05** | Hume 동시 접속 상한 대응 — **6번째 연결은 대기가 아니라 `E0700` 거절**이라(Hume 오류 문서), 순번을 보여주려면 대기열을 우리가 만들어야 한다. ① **§2-14 신설**(`GET`·`DELETE /api/session/queue/{ticketId}`) — **`position: 0` 응답에 세션이 동봉되고 그것이 입장권**이다. 예약 단계가 없어 만료 타이머·가로채기가 성립하지 않는다 ② **§2-4에 202 추가** — 정원이 차면 세션 대신 순번. `SESSION_QUEUE_ENABLED` 기본 `false`라 **꺼진 상태에서는 202가 나가지 않고 경로가 도입 전과 같다** ③ 정원 판정은 Hume `chats?status=ACTIVE`(실측 200). 우리 열린 세션 행을 세면 **Hume 슬롯(비활성 2분)과 우리 행(30분)의 수명이 달라 빈 자리를 두고 막는다**. **필드 변경 없음, 엔드포인트 2개 신설**(§5 S02 행 갱신) |
| **v1.8** | **2026-09-05** | `chat-group-id.md` 회신 반영 — 앱이 **`chat_group_id`를 소켓 직후 `chat_metadata`로 받는다**고 확인했다. ① **§2-5-2 신설** — `POST /api/session/{id}/chat-group`, 멱등·204. `end` 본문이 아니라 별도 엔드포인트인 이유는 **강제 종료된 세션을 덮는 경로가 그것뿐**이기 때문이다(그리고 이어하기가 필요한 상황이 정확히 그 상황이다). 종료된 세션에도 받고, 값이 바뀌면 마지막 값이 이긴다 ② **§2-5-1 `resumedChatGroupId`의 빈 값을 `null`로 확정**하고 §1-3 표에 행 추가 — 앱이 빈 문자열을 "없음"으로 방어하고 있었다. **필드 변경 없음, 엔드포인트 1개 신설** |
| **v1.7** | **2026-09-05** | `session-id-in-url.md` 회신 — **§1-1에 `sessionId`의 앱 URL 노출 허용과 근거를 명시**했다. 앱이 대화 상세를 `#/records/{sessionId}`로 라우팅하는데 §1-1의 "로그에 남기지 않는다"만 보면 모순으로 읽히기 때문이다. 허용의 근거는 **그 값이 구조적으로 쓸 수 없는 값**이라는 것이고(목록은 종료 세션만 → CLM 401 → 재개 불가), 셋 다 백엔드가 실측했다. **해시 라우팅이 전제이며 path 전략으로 바꾸면 무효**임을 조건으로 달았다. **필드 변경 없음** |
| **v1.6** | **2026-09-05** | `kakao-web-login.md` 회신 반영 — **웹에서는 앱이 카카오 액세스 토큰을 받을 수 없다**(앱이 SDK 2.0.1 소스로 확인: 웹 로그인 API가 전부 `notSupported`, `authorize()`는 빈 문자열 반환). ① **§2-1 요청을 `kakaoAccessToken` → `kakaoAuthCode` + `redirectUri`로 교체.** 서버가 인가 코드를 토큰으로 교환한다. `redirectUri`는 등록 목록과 대조해 아니면 400 — 인가 코드를 남의 주소로 흘릴 수 있는 자리다. **응답은 그대로**(`jwt`·`expiresAt`·`profileId`·`isNewUser`) ② **§2-1 오류 표 갱신** — 400에 `redirectUri` 미등록 추가, 401 사유를 코드 교환 실패로 ③ **§2-3에 선택 본문 신설** — 탈퇴 시 카카오 unlink용 인가 코드. **없어도 204**이며 unlink 실패는 오류로 올리지 않는다. 리프레시 토큰을 보관하지 않기로 한 결정의 결과다. **필드 삭제 1건(`kakaoAccessToken`) — 앱·백엔드 모두 이 회차에 맞춘다** |
| v1.0 | 2026-09-03 | 최초 작성. PRD §8·spec 기준으로 12개 공개 엔드포인트 + 2개 내부 엔드포인트 확정 |
| v1.1 | 2026-09-03 | 문서 교차 검증 반영 — ① `POST /api/session/{id}/resume` 신설(중단 세션 이어하기) ② `POST /api/observations/{id}/feedback` 신설(측정 절차가 없던 §1.4 "맞아요" 지표를 실제로 수집 가능하게) ③ `GET /api/me`에 `openSession` 추가 ④ `endReason`에 `timeout`·`resumed` 추가 ⑤ 409 `SESSION_NOT_RESUMABLE` 추가 ⑥ JWT 만료 7일 명시 ⑦ `gapThreshold` 예시값 표기 |
| v1.2 | 2026-09-03 | AI 파이프라인 개정 반영(`request/ai/clm-turn-pipeline-review.md` 회신) — ① §1-3 `textValence` null 사유를 "분석 호출 실패·타임아웃"으로 ② §4 마지막 경고를 "메타 태그 없음"으로, CLM 인증 방향 각주 ③ 상위 문서에 `ai-pipeline.md` 추가 ④ §1-3 `voiceValence` null 사유에 합계 질량 부족(중립만 찍힌 발화) 추가. **필드 변경 없음.** 계약 공백 2건은 별도 요청(`request/backend/session-context-lookup.md`, `session-summary-endpoint.md`)으로 다음 버전에서 |
| **v1.5** | **2026-09-04** | `turn-index-numbering.md` 회신 — §3-2 필드 표에 **`occurredAt` 규칙 행 신설**(발화 시각 · RFC 3339 **밀리초 정밀도** · 재시도는 최초 시도와 동일 문자열 · 같은 세션의 서로 다른 발화는 값이 겹치지 않음). 백엔드의 `unique (session_id, turn_index)` 충돌 판별이 이 필드에 걸려 있어 규칙을 명시했다. §3-2 예시를 밀리초로 교체. **필드 추가·삭제·개명 없음** |
| **v1.4** | **2026-09-04** | 백엔드 계획 문서를 루트 스펙과 전수 대조하며 나온 공백 5건 — ① **§2-8에 `userAvgGap`·`tagGaps` 추가**(F9-03 출력의 데이터 경로. `range` 종속, 3회 이상 필터는 서버, `tagAvgGap` 내림차순 상위 7개) — `tag-gap-endpoint.md` 회신 ② **§2-8 `highlights` 판정 기준을 `voice_session.gap_threshold` 스냅샷으로 명시**(현재 설정값으로 소급 판정하면 임계값 확정 시 과거 음영이 통째로 바뀐다) ③ **§3-2에 `turnIndex` 채번 규칙 명시**(이어하기 재연결 후 이어 붙임 — 리셋하면 중복 방어에 걸려 턴이 조용히 유실된다) ④ **§3-4 응답에 `lastTurnIndex` 추가**(③의 근거) ⑤ §2-5 각주 "배치 큐 적재" → `pattern_processed_at` 방식으로 정정. **필드 삭제·개명 없음** |
| **v1.3** | **2026-09-03** | 백엔드가 받은 요청 4건 회신 — ① `sessionId`를 `sess_`+짧은 문자열에서 **UUIDv4(접두사 없음)로 교체**(전 예시 반영, §1-1에 로깅 금지 규칙 추가) ② §2-4·§2-5-1에 **`humeConfigId`**(null 불가, 기동 시 fail-fast) 추가 — `hume-config-id.md` ③ §2-4에 **`livePollIntervalSec`** 추가, **§2-13 `GET /api/session/{id}/live` 신설**(비데모는 `turns: []`, `crisisDetected`는 세션 단위) — `live-turn-signal.md` ④ **§3-4 `GET /internal/sessions/{id}` 신설**(CLM 인증 겸용, 캐시 미스 시 fail-closed 401), §4 CLM 인증을 `custom_session_id` 검증으로 확정 — `session-context-lookup.md` ⑤ **§3-5 `POST /internal/summaries` 신설**(동기 3초, `endReason: timeout`은 미호출), §2-5에 각주 — `session-summary-endpoint.md` ⑥ §3-2 `/internal/turns` 재시도 1회 → **3회**(전 세션 동일) ⑦ §5 S02·S07 행 갱신 |
