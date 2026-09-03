# Phase 2 — 대화 세션

> 목표: **앱이 EVI에 연결해 대화를 시작하고 끝낼 수 있는 상태**를 만든다. 턴 로그 적재는 아직 없어도 된다.
>
> 의존: Phase 1의 JWT 필터 · `voice_session` 테이블 · 스케줄러 뼈대
>
> 근거: `spec.md` F2-01·F2-05·F2-06·F2-07, F3-04 · `api-contract.md` §2-4·§2-5·§2-5-1·§3-4·§3-5

> **이 Phase가 앱과 AI를 동시에 푼다.** 앱은 `POST /api/session/start` 없이 EVI에 붙지 못하고, AI는 `GET /internal/sessions/{id}` 없이 CLM 인증을 통과하지 못한다(계약 §4). 착수 순서에서 가장 앞에 두는 이유다 — `roadmap.md`.

## 2-1. 세션 시작 — `POST /api/session/start` (F2-01)

- [ ] `voice_session` 생성 — **`id`는 UUIDv4**(`gen_random_uuid()`). 계약 §1-1
- [ ] **그 사용자의 열린 세션을 먼저 닫는다** (`end_reason: 'timeout'`) — 동시 세션 문제를 별도 잠금 없이 해결(F2-06 부수 효과)
- [ ] `user_baseline.session_count` 조회 → **`< 5`면 `fixed`, `>= 5`면 `personal`** (F3-04). `voice_session.threshold_mode`에 기록
- [ ] Hume 단기 액세스 토큰 발급 (백엔드 환경변수의 API 키로)
- [ ] 응답 조립 — 계약 §2-4 (v1.3)

```json
{ "sessionId", "humeAccessToken", "humeTokenExpiresAt", "humeConfigId",
  "thresholdMode", "gapThreshold", "softWrapSec", "hardCutSec",
  "livePollIntervalSec", "demoMode" }
```

| 필드 | 값 · 규칙 |
| --- | --- |
| `humeConfigId` | **환경변수에서 읽는다.** AI서버가 생성·소유한 Config ID를 전달만 한다 |
| `livePollIntervalSec` | **2**. §2-13 폴링 간격을 앱이 상수로 박지 않게 서버가 내려준다 |
| `softWrapSec`·`hardCutSec` | **300 / 420 고정** |
| `gapThreshold` | 초기 수치는 20쌍 측정 후 결정(PRD §14-5). **그때까지 `.env` 값을 그대로 내려준다** |
| `demoMode` | 계정 단위 플래그 (Phase 7에서 실제로 켠다. 지금은 항상 false여도 됨) |

- [ ] Hume 토큰 발급 실패 → **503 `HUME_TOKEN_ISSUE_FAILED`**. 앱은 대화 시작을 차단한다
- [ ] **`HUME_CONFIG_ID` 환경변수가 없으면 서버가 기동하지 않게 한다**(필수 프로퍼티) — 아래 주의

> **`humeConfigId`는 null이 될 수 없다**(계약 §2-4). 환경변수 값이라 "발급 실패"라는 게 없고, 없다면 그건 **배포 설정 오류**다. 런타임 503으로 만들면 서버는 멀쩡히 떠 있는데 모든 세션 시작이 실패하고, 원인 추적이 "Hume이 왜 이러지"에서 시작해 한참 돌아 설정 파일에 도착한다. **기동 시 죽는 편이 낫다.**

> **Hume 유료 플랜이 여기서 걸린다.** Free는 **월 5분**이라 이 API를 실제로 붙여보는 첫 테스트에 소진된다 — `roadmap.md` 착수 블로커.

## 2-2. 세션 컨텍스트 조회 — `GET /internal/sessions/{sessionId}` (v1.3 신설)

AI서버 → 백엔드. **CLM 인증을 겸한다**(계약 §4).

- [ ] 헤더 `X-Internal-Secret` 검증 → 불일치 401 `INTERNAL_AUTH_FAILED` (계약 §3-1)
- [ ] 응답 — 계약 §3-4

```json
{ "sessionId", "status", "startedAt", "usedSec", "thresholdMode",
  "gapThreshold", "softWrapSec", "hardCutSec", "demoMode", "recentObservations" }
```

- [ ] `status`는 `"open"` | `"ended"`. **`ended`도 200으로 반환**한다 — 401로 바꾸는 판단은 AI서버 몫이다(계약 §3-4)
- [ ] 없는 `sessionId` → **404**
- [ ] `recentObservations`는 최근 3개. **Phase 4 전에는 빈 배열**이다 (관찰이 아직 없으므로 정상)
- [ ] `transcript`류는 **넣지 않는다**

> **AI서버는 세션당 1회만 부르고 `hardCutSec + 30분` TTL로 캐시한다.** 실시간 경로에 매 턴 홉이 붙지 않게 한 설계이므로, 백엔드는 이 호출이 자주 오지 않는다고 가정해도 된다.
> **AI서버는 조회 실패 시 fail-closed로 401을 Hume에 돌려준다.** 즉 이 엔드포인트가 죽으면 **새 대화가 시작되지 않는다.** `/internal/turns`(fire-and-forget)와 성격이 다르다 — 이건 실시간 경로의 필수 의존이다.

## 2-3. 세션 종료 — `POST /api/session/{id}/end` (F2-05)

- [ ] `ended_at` · `duration_sec` · `end_reason` 기록
- [ ] **요약 생성** — `endReason`이 `user_end`·`soft_wrap`·`hard_cut`이면 §3-5 `POST /internal/summaries`를 **동기 호출**(타임아웃 3초)
  - [ ] 실패·타임아웃·422 → **재시도하지 않고 `summary: null`**
  - [ ] **`endReason: "timeout"`이면 호출하지 않고 항상 `null`** — 아래 주의
- [ ] 응답 `{ sessionId, durationSec, turnCount, summary, gapAvg }` — 계약 §2-5
- [ ] `gapAvg`는 그 세션 턴들의 평균. **갭이 NULL인 턴은 제외**
- [ ] 404 `SESSION_NOT_FOUND` / 403 `FORBIDDEN`(타 사용자 세션)

> **`timeout` 종료에서 요약을 만들지 않는 이유** — 세션 종료는 사용자만 부르는 게 아니라 F2-06 스케줄러도 부른다. 밀린 세션을 여러 건 정리할 때 건당 3초씩 기다리면 스케줄러가 느려지고, 그 세션들은 애초에 **아무도 보고 있지 않다.**

> **배치 큐 적재는 별도 동작이 아니다.** `ended_at`이 기록되고 `pattern_processed_at`이 NULL이면 그 자체가 "미처리"다(F7-01, `data-model.md`). 여기서 큐에 넣는 코드를 따로 쓰지 않는다.

## 2-4. 미종료 세션 자동 정리 (F2-06)

- [ ] Phase 1의 스케줄러에 태운다 — **추가 인프라 0**
- [ ] 시작 후 **30분** 경과 + `ended_at IS NULL` → `end_reason: 'timeout'`으로 종료
- [ ] 요약은 만들지 않는다 (2-3 참조)

> **왜 P0인가** — 이게 없으면 앱 강제 종료·배터리 방전으로 끊긴 세션이 열린 채 남고, `pattern_processed_at`이 영영 NULL이라 **배치가 돌지 않아 그 대화가 관찰 집계에서 통째로 빠진다.** 도그푸딩 하루치가 사라지는 것과 같다.

## 2-5. `GET /api/me`의 `openSession` (F2-07 준비)

- [ ] Phase 1에서 `null`로 두었던 필드를 채운다 — 계약 §2-2
- [ ] `{ sessionId, startedAt, usedSec, remainingSec, resumableUntil }`
- [ ] **`resumableUntil`은 컬럼이 아니라 `ended_at + 30분` 계산값**이다(`data-model.md`)

## 2-6. 중단 세션 이어하기 — `POST /api/session/{id}/resume` (F2-07, **P1**)

- [ ] `remainingSec = hardCutSec − usedSec`. **새 7분을 주지 않는다**
- [ ] `humeConfigId` 재포함 — 같은 Config로 붙어야 CLM이 이어진다
- [ ] `resumedChatGroupId` 반환 (`voice_session.hume_chat_group_id`)
- [ ] 이어하기 창(30분) 경과 또는 `remainingSec <= 0` → **409 `SESSION_NOT_RESUMABLE`**

> **P1이라 잘려도 된다**(spec §11 스코프 컷 3번). F2-06이 데이터를 지키므로 없어도 유실은 없다. **잘라도 `openSession`(2-5)은 남긴다** — 앱이 "중단된 대화가 있다"를 표시하고 새로 시작하게 하는 데 쓴다.

## 완료 기준

- 앱이 `POST /api/session/start` 응답만으로 EVI에 연결된다 (`humeConfigId` 포함)
- AI서버가 `GET /internal/sessions/{id}`로 세션을 검증하고 임계값을 받아간다
- **TC-02** — 대화 시작 → 3분 → 종료 시 세션이 정상 기록되고 요약이 표시된다
- **TC-03** — 앱 번들·네트워크 응답 어디에도 **Hume API 키가 없다** (단기 토큰만)
- **TC-07** — 5회차 세션에서 `thresholdMode`가 `personal`로 전환된다 (Phase 3의 baseline과 함께 확인)
- **TC-21** — 대화 중 앱 강제 종료 → 30분 뒤 세션이 `timeout`으로 닫힌다
- **TC-22** — 강제 종료 5분 뒤 이어하기 시 **남은 시간이 7분이 아니라 잔여분**이다 (P1)
- `api-spec.md` 구현 현황 갱신 (`session/start`·`end`·`resume`·`internal/sessions`)

## 이 Phase에서 하지 않는 것

- **턴 로그 수신** (`/internal/turns`) — Phase 3
- **`/internal/summaries`의 AI 쪽 구현** — AI 담당. 백엔드는 호출만 하고 실패 시 `null`
- **`recentObservations` 실제 값 채우기** — Phase 4에서 관찰이 생긴 뒤
- **`demoMode` 플래그 운영** — Phase 7
- `gapThreshold` 수치 확정 — 20쌍 측정 후 (PRD §14-5). 지금은 `.env` 값을 통과시킨다
