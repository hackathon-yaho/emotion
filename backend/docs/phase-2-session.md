# Phase 2 — 대화 세션

> 목표: **앱이 EVI에 연결해 대화를 시작하고 끝낼 수 있는 상태**를 만든다. 턴 로그 적재는 아직 없어도 된다.
>
> 의존: Phase 1의 JWT 필터 · `voice_session` 테이블 · 스케줄러 뼈대
>
> 근거: `spec.md` F2-01·F2-05·F2-06·F2-07, F3-04 · `api-contract.md` §2-4·§2-5·§2-5-1·§3-4·§3-5 (**v1.4**)
>
> **상태 (2026-09-04): 코드 완료 · 테스트 36건 통과(Phase 1 18 + Phase 2 18) · 로컬 기동 확인.**
> 막혀 있는 것은 **Hume 키 3개**(`HUME_API_KEY`·`HUME_SECRET_KEY`·`HUME_CONFIG_ID`, AI 소유 계정 — `../../docs/request/ai/hume-account-setup.md` ⏳)뿐이다. 자리표시가 들어 있어 **`POST /api/session/start`는 지금 503 `HUME_TOKEN_ISSUE_FAILED`로 떨어지며, 이게 정상 동작이다.** 나머지 경로(세션 생성·종료·이어하기·`/internal/sessions`·스케줄러 정리)는 전부 검증했다.
> **`POST /internal/summaries` 호출은 Phase 3으로 미뤘다** — 아래 2-3.

> **응답 필드는 여기 옮겨 적지 않는다.** 계약 §번호를 열어 보고, 여기서는 계약이 정하지 않은 백엔드 쪽 판단만 확인한다 — [README](README.md) "이 문서를 쓰는 법" 4번.

> **이 Phase가 앱과 AI를 동시에 푼다.** 앱은 `POST /api/session/start` 없이 EVI에 붙지 못하고, AI는 `GET /internal/sessions/{id}` 없이 CLM 인증을 통과하지 못한다(계약 §4). 착수 순서에서 가장 앞에 두는 이유다 — `roadmap.md`.

## 2-1. 세션 시작 — `POST /api/session/start` (F2-01)

- [x] `voice_session` 생성 — **`id`는 UUIDv4**(`gen_random_uuid()`). 계약 §1-1
- [x] **그 사용자의 열린 세션을 먼저 닫는다** (`end_reason: 'timeout'`) — 동시 세션 문제를 별도 잠금 없이 해결(F2-06 부수 효과)
- [x] `user_baseline` 조회 → **`session_count >= 5` AND `avg_gap IS NOT NULL`이면 `personal`, 아니면 `fixed`** (F3-04). `voice_session.threshold_mode`에 기록
- [x] **적용 임계값을 `voice_session.gap_threshold`에 스냅샷** (2026-09-04 신설) — 아래 주의
- [x] Hume 단기 액세스 토큰 발급 — `POST https://api.hume.ai/oauth2-cc/token`에 **API 키·Secret 키를 Basic 인증으로** 보내 `client_credentials`로 받는다(만료 30분, 하드컷 7분이라 넉넉하다). **두 값 모두 AI에게서 받는다**(계정을 AI가 소유, `../../docs/request/ai/hume-account-setup.md`). **키가 자리표시인 지금은 503으로 떨어지는 것이 정상이며, 그때 세션을 만들지 않는다** — 토큰을 먼저 받고 그다음에 이전 세션을 닫는다. 순서를 뒤집으면 발급 실패 때 사용자가 대화도 못 시작하고 이어하기 대상까지 잃는다
- [x] 응답 조립 — **필드는 계약 §2-4가 단일 출처다**(v1.4). 아래는 계약이 정하지 않은 백엔드 쪽 판단만 적는다

| 필드 | 백엔드가 정하는 것 |
| --- | --- |
| `humeConfigId` | **환경변수에서 읽는다.** AI서버가 생성·소유한 Config ID를 전달만 한다 |
| `livePollIntervalSec` | **2** |
| `softWrapSec`·`hardCutSec` | **300 / 420 고정** |
| `gapThreshold` | 초기 수치는 20쌍 측정 후 결정(PRD §14-5). **그때까지 `.env` 값을 그대로 내려준다.** 어느 값이든 `gap_threshold`에 그대로 저장한다 |
| `demoMode` | **`profile.demo_mode`**를 읽어 내려준다 (2026-09-04 확정. 값은 Phase 7까지 전부 `false`) |

> **`avg_gap IS NOT NULL` 가드를 빼지 않는다** (spec F3-04, 2026-09-04). 5세션 내내 분석 호출이 실패하면(TC-06 반복) 갭이 한 건도 없어 `avg_gap`이 NULL인데, 세션 수만 보면 그 상태로 `personal`로 넘어간다 — **평균이 없는데 "개인 평균 ± 표준편차"를 계산하게 된다.**

> **`gap_threshold` 스냅샷이 F9-02를 지킨다.** 이 값을 안 남기면 트렌드의 음영 구간(계약 §2-8 `highlights`)이 **판정할 기준을 잃는다.** 임계값은 20쌍 측정 후 확정되므로 반드시 한 번 바뀌고, 현재값으로 소급 판정하면 그날 실제로 되물었던 근거와 화면이 어긋난다.

- [x] Hume 토큰 발급 실패 → **503 `HUME_TOKEN_ISSUE_FAILED`**. 앱은 대화 시작을 차단한다
- [x] **`HUME_CONFIG_ID` 환경변수가 없으면 서버가 기동하지 않게 한다**(필수 프로퍼티) — 아래 주의

> **`humeConfigId`는 null이 될 수 없다**(계약 §2-4). 환경변수 값이라 "발급 실패"라는 게 없고, 없다면 그건 **배포 설정 오류**다. 런타임 503으로 만들면 서버는 멀쩡히 떠 있는데 모든 세션 시작이 실패하고, 원인 추적이 "Hume이 왜 이러지"에서 시작해 한참 돌아 설정 파일에 도착한다. **기동 시 죽는 편이 낫다.**

> **Hume 유료 플랜이 여기서 걸린다.** Free는 **월 5분**이라 이 API를 실제로 붙여보는 첫 테스트에 소진된다 — `roadmap.md` 착수 블로커.

## 2-2. 세션 컨텍스트 조회 — `GET /internal/sessions/{sessionId}` (v1.3 신설)

AI서버 → 백엔드. **CLM 인증을 겸한다**(계약 §4).

- [x] 헤더 `X-Internal-Secret` 검증 → 불일치 401 `INTERNAL_AUTH_FAILED` (계약 §3-1)
- [x] 응답 — **필드는 계약 §3-4가 단일 출처다**(v1.4)
- [x] **`lastTurnIndex`**(v1.4) — 그 세션에 적재된 `max(turn_index)`, 없으면 `0`. AI서버가 이어하기 재연결 시 인덱스를 여기서부터 이어 붙인다 — 아래 주의
- [x] `gapThreshold`는 **`voice_session.gap_threshold`(스냅샷)를 읽어 내려준다.** `.env` 현재값을 다시 읽지 않는다 — 세션 중에 값이 바뀌면 앱과 AI가 다른 임계값을 쓰게 된다
- [x] `status`는 `"open"` | `"ended"`. **`ended`도 200으로 반환**한다 — 401로 바꾸는 판단은 AI서버 몫이다(계약 §3-4)
- [x] 없는 `sessionId` → **404**
- [x] `recentObservations`는 최근 3개. **Phase 4 전에는 빈 배열**이다 (관찰이 아직 없으므로 정상)
- [x] `transcript`류는 **넣지 않는다**

- [x] **응답이 빨라야 한다** — AI는 `AI_SESSION_LOOKUP_TIMEOUT_MS` 800ms(통합 중 2000ms)로 끊고, 타임아웃이면 **fail-closed로 401**이라 새 대화가 시작되지 않는다
  - **로컬 실측 11~20ms**(첫 호출 106ms, 2026-09-04). 예산의 2% 수준이다
  - **남은 위험은 쿼리 수가 아니라 Render Free의 콜드 스타트다** — 15분 슬립 뒤 첫 요청은 800ms를 훨씬 넘긴다. cron 킵얼라이브(10분, Phase 7)가 그걸 막는 장치이므로, **배포 때 킵얼라이브를 빠뜨리면 이 엔드포인트가 첫 대화마다 실패한다**

> **AI서버는 세션당 1회만 부르고 `hardCutSec + 30분` TTL로 캐시한다.** 실시간 경로에 매 턴 홉이 붙지 않게 한 설계이므로, 백엔드는 이 호출이 자주 오지 않는다고 가정해도 된다.
> **`lastTurnIndex`는 "적재된 최대 `turnIndex`"다 — "적재 건수"가 아니다.** 4xx로 버려진 턴이 있으면 두 값이 갈리고, AI가 이 값에서 채번을 이어 붙이므로 정의를 바꾸면 번호가 어긋난다(AI 회신에서 이 정의를 유지해 달라고 확인받았다).
> **이어하기 감지는 AI서버가 유휴 60초로 한다** — Hume 요청에 "재연결 직후"라는 신호가 없어서, 턴 사이 공백이 `AI_SESSION_REFETCH_IDLE_SEC`를 넘으면 캐시를 버리고 이 엔드포인트를 다시 부른다. **백엔드는 세션 중 이 호출이 두어 번 더 올 수 있다고 보면 된다.**
> **`lastTurnIndex`가 없으면 이어하기가 턴을 삼킨다** (2026-09-04, 계약 v1.4). 이어하기는 같은 `sessionId`를 유지하는데, AI서버가 재연결 후 `turnIndex`를 0부터 다시 시작하면 `unique (session_id, turn_index)`에 걸린다. 백엔드는 그 위반을 **"이미 적재됨"으로 보고 202를 돌려주므로**(3회 재시도 대응, Phase 3) **이후의 모든 새 턴이 오류 없이 버려진다.** 채번 규칙은 계약 §3-2에 명시했고 AI 확인 요청이 진행 중이다 — `../../docs/request/ai/turn-index-numbering.md` ⏳.
> **AI서버는 조회 실패 시 fail-closed로 401을 Hume에 돌려준다.** 즉 이 엔드포인트가 죽으면 **새 대화가 시작되지 않는다.** `/internal/turns`(fire-and-forget)와 성격이 다르다 — 이건 실시간 경로의 필수 의존이다.

## 2-3. 세션 종료 — `POST /api/session/{id}/end` (F2-05)

- [x] `ended_at` · `duration_sec` · `end_reason` 기록
- [x] **요약 생성** — `endReason`이 `user_end`·`soft_wrap`·`hard_cut`이면 §3-5 `POST /internal/summaries`를 **동기 호출**(타임아웃 3초) → **Phase 3에서 구현했고 2026-09-05에 성공 경로까지 확인**
  - [x] 실패·타임아웃·422 → **재시도하지 않고 `summary: null`**
  - [x] **`endReason: "timeout"`이면 호출하지 않고 항상 `null`** — 아래 주의

> **왜 Phase 3인가** (2026-09-04). §3-5는 **턴 텍스트를 보내는** 호출인데, 턴이 들어오는 것도(`/internal/turns`) 그 본문을 평문으로 읽는 복호화 변환기도 Phase 3에서 생긴다. 지금 붙이면 **호출할 데이터가 0건이라 실행되는 경로가 없는 코드**가 남는다. 계약 §2-5가 `summary: null`을 허용하므로 지금 항상 null인 것은 계약 위반이 아니다 — 턴이 없으니 요약할 것도 없다.
- [x] **`user_baseline.session_count` +1** — F3-05가 아니라 **종료의 기본 동작**이다(spec F3-05, 2026-09-04 분리). F3-05를 잘라도 이건 남는다
- [x] 응답 — 필드는 계약 §2-5
- [x] `gapAvg`는 그 세션 턴들의 평균. **갭이 NULL인 턴은 제외**
- [x] 404 `SESSION_NOT_FOUND` / 403 `FORBIDDEN`(타 사용자 세션)

> **`timeout` 종료에서 요약을 만들지 않는 이유** — 세션 종료는 사용자만 부르는 게 아니라 F2-06 스케줄러도 부른다. 밀린 세션을 여러 건 정리할 때 건당 3초씩 기다리면 스케줄러가 느려지고, 그 세션들은 애초에 **아무도 보고 있지 않다.**

> **배치 큐 적재는 별도 동작이 아니다.** `ended_at`이 기록되고 `pattern_processed_at`이 NULL이면 그 자체가 "미처리"다(F7-01, `data-model.md`). 여기서 큐에 넣는 코드를 따로 쓰지 않는다.

## 2-4. 미종료 세션 자동 정리 (F2-06)

- [x] Phase 1의 스케줄러에 태운다 — **추가 인프라 0**
- [x] **마지막 발화 후 30분** 경과 + `ended_at IS NULL` → `end_reason: 'timeout'`으로 종료 (2026-09-04 정정 — 아래 주의)
- [x] 요약은 만들지 않는다 (2-3 참조)

> **왜 P0인가** — 이게 없으면 앱 강제 종료·배터리 방전으로 끊긴 세션이 열린 채 남고, `pattern_processed_at`이 영영 NULL이라 **배치가 돌지 않아 그 대화가 관찰 집계에서 통째로 빠진다.** 도그푸딩 하루치가 사라지는 것과 같다.

## 2-5. `GET /api/me`의 `openSession` (F2-07 준비)

- [x] Phase 1에서 `null`로 두었던 필드를 채운다 — 필드는 계약 §2-2
- [x] **`resumableUntil`은 컬럼이 아니라 계산값**이다 — `마지막 발화 시각 + 30분`(`data-model.md`, 2026-09-04 정정)

> **`ended_at + 30분`으로는 계산할 수 없다** (구현 중 발견). `openSession`은 **아직 열려 있는** 세션이라 `ended_at`이 NULL이다. `started_at + 30분`으로 두면 이번엔 **TC-22가 깨진다** — 2분 말하고 앱이 죽은 뒤 5분 지나 이어하기를 누르면 벽시계로 7분이 흘러 잔여 시간이 0이 되고 409로 막힌다. 앱이 죽으면 종료 신호가 오지 않으므로 **서버가 아는 마지막 활동은 마지막 턴의 `occurred_at` 하나뿐**이고, `usedSec`·이어하기 창·F2-06 정리가 전부 이 값에서 갈린다. 턴이 없으면 `started_at`이다. 계약 §2-2의 정의("중단 후 30분")와도 이쪽이 맞는다.

## 2-6. 중단 세션 이어하기 — `POST /api/session/{id}/resume` (F2-07, **P1**)

- [x] `remainingSec = hardCutSec − usedSec`. **새 7분을 주지 않는다**
- [x] `humeConfigId` 재포함 — 같은 Config로 붙어야 CLM이 이어진다
- [x] `gapThreshold`는 **그 세션의 `gap_threshold` 스냅샷**을 그대로. 이어하기는 같은 세션이므로 임계값이 바뀌지 않는다
- [x] `resumedChatGroupId` 반환 (`voice_session.hume_chat_group_id`) — **값이 없으면 `null`이다**(계약 §1-3, v1.8). 빈 문자열로 내리지 않는다
- [x] **`POST /api/session/{id}/chat-group` 신설** (계약 §2-5-2, v1.8, 2026-09-05) — 앱이 소켓 직후 받는 `chat_group_id`를 올린다. **멱등·204**, 종료된 세션에도 받는다, 마지막 값이 이긴다
- [x] 이어하기 창(30분) 경과 또는 `remainingSec <= 0` → **409 `SESSION_NOT_RESUMABLE`**

> **P1이라 잘려도 된다**(spec §11 스코프 컷 3번). F2-06이 데이터를 지키므로 없어도 유실은 없다. **잘라도 `openSession`(2-5)은 남긴다** — 앱이 "중단된 대화가 있다"를 표시하고 새로 시작하게 하는 데 쓴다.

## 완료 기준

- ⏳ 앱이 `POST /api/session/start` 응답만으로 EVI에 연결된다 (`humeConfigId` 포함)
  - ✅ **실물 토큰이 나간다** (2026-09-05) — 키가 들어와 `201` + 실제 `humeAccessToken`(`expires_in` 1799초). **EVI 시간 0초**로 확인했다(소켓 미개방)
  - 🐛 **그 과정에서 결함 1건** — Hume 토큰 엔드포인트가 **200에 `Content-Type`을 안 싣는다.** `Map`으로 받으면 `UnknownContentTypeException`이 나고 **키가 틀린 것과 똑같은 503**으로 보인다. `String` 파싱으로 고치고 회귀 테스트 추가
  - ⏳ 남은 것은 **Config**다 — `language_model`이 `null`이라 **CLM이 안 붙어 있다**(`blocked.md` ①)
- ✅ AI서버가 `GET /internal/sessions/{id}`로 세션을 검증하고 임계값을 받아간다 — 시크릿 없이 401, 없는 세션 404, `ended`도 200
- ⏳ **TC-02** — 대화 시작 → 3분 → 종료 시 세션이 정상 기록되고 요약이 표시된다
  - ✅ **요약 성공 경로가 돌았다** (2026-09-05) — 대역 AI서버로 `POST /internal/summaries`를 받아 `summary`가 종료 응답에 실렸다. Phase 3에서 호출을 붙인 뒤 **성공 경로는 한 번도 안 돌아본 상태**였다(진짜 AI서버는 키가 없어 422)
  - ⏳ 남은 것은 **Hume으로 실제 3분 대화**다 — Hume 키와 LLM 키(`GOOGLE_API_KEY`)가 들어와야 한다
- ⏳ **TC-03** — 앱 번들·네트워크 응답 어디에도 **Hume API 키가 없다** (단기 토큰만) — 서버 응답에 키가 없는 것은 구조상 확정(`HumeTokenService`가 토큰만 반환). **앱 번들 확인은 앱이 붙인 뒤**
- ✅ **TC-07** — 5회차 세션에서 `thresholdMode`가 `personal`로 전환된다 — 전환과 **`avg_gap` NULL 가드**를 각각 테스트로 못 박았다
- ✅ **TC-21** — 대화 중 앱 강제 종료 → 30분 뒤 세션이 `timeout`으로 닫힌다 — 창 안의 세션은 건드리지 않는 것까지 확인
- ✅ **TC-22** — 강제 종료 5분 뒤 이어하기 시 **남은 시간이 7분이 아니라 잔여분**이다 (P1)
- ✅ `api-spec.md` 구현 현황 갱신 (`session/start`·`end`·`resume`·`internal/sessions`)

> **~~`resumedChatGroupId`를 채우는 경로가 아직 없다~~ — 2026-09-05에 뚫렸다.** 앱이 **소켓이 열린 직후 `chat_metadata`로 값을 받는다**고 회신했고, `POST /api/session/{id}/chat-group`(계약 §2-5-2)을 신설해 받는다. **`end` 본문이 아니라 별도 엔드포인트인 이유**는 앱이 강제 종료되면 `end` 호출 자체가 없는데 **이어하기가 필요한 상황이 정확히 그 상황**이기 때문이다. 아래는 발견 당시의 기록이다.
>
> <sub>(2026-09-04, 구현 중 발견)</sub> 계약 §2-5-1이 이어하기 응답에 이 값을 요구하는데, `voice_session.hume_chat_group_id`에 **쓰는 주체가 어느 문서에도 없다.** EVI의 `chat_group_id`는 앱이 Hume과 직접 붙어서 받는 값이라 백엔드가 스스로 알 수 없다. 지금은 항상 null이고, 그러면 **이어하기가 되긴 하지만 이전 대화 맥락이 복원되지 않는다.** 앱에 확인 요청을 보냈다 — `../../docs/request/app/chat-group-id.md`.

## 이 Phase에서 하지 않는 것

- **턴 로그 수신** (`/internal/turns`) — Phase 3
- **`/internal/summaries`의 AI 쪽 구현** — AI 담당. 백엔드는 호출만 하고 실패 시 `null`
- **`recentObservations` 실제 값 채우기** — Phase 4에서 관찰이 생긴 뒤
- **`demoMode` 플래그 운영** — Phase 7
- `gapThreshold` 수치 확정 — 20쌍 측정 후 (PRD §14-5). 지금은 `.env` 값을 통과시킨다
