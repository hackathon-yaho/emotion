# API 구현 현황 — 백엔드

> **수정 기록 (2026-09-04 ⑤)** — **Phase 1 구현.** `POST /api/auth/kakao`·`GET /api/me`·`GET /api/health` 3건 구현 완료. `DELETE /api/account`는 계약대로 204를 주지만 **라우트와 인증만** 걸려 있고 삭제 로직은 Phase 6이다. 계약과 다르게 동작하는 부분은 없어 아래 절은 비워 둔다.
>
> **수정 기록 (2026-09-05 ⑧)** — **Phase 5 구현 완료.** 조회 6개 — 관찰 목록·근거·피드백 · 트렌드(`points`·`highlights`·`userAvgGap`·`tagGaps`) · 대화 기록 목록·상세. **`range`를 생략하면 `GET /api/trend`가 500이던 것을 고쳤다**(`Map.of().containsKey(null)`). **기록 목록은 끝난 세션만** 내려간다.

> **수정 기록 (2026-09-05 ⑦)** — **Phase 4 구현 완료.** 패턴 배치가 스케줄러에 올라갔다 — 태그별 집계(전체 기간, 갭 NULL 제외) → **코드 판정**(3회 이상 AND 1.5배 이상) → 통과한 것만 `POST /internal/observations`로 문장화 → `observation` + `observation_evidence`. **`/internal/sessions`의 `recentObservations`가 이제 실제 값이다.** AI서버가 없어 **지금은 관찰이 0건이고 그게 설계대로다**(템플릿 폴백 없음).

> **수정 기록 (2026-09-05 ⑥)** — **Phase 3 구현 완료.** `POST /internal/turns`(암호화 저장·태그·위기·중복 판별) · `GET /api/session/{id}/live` · `POST /internal/summaries` 호출 · F3-05 baseline 재계산. **AI서버 고정 픽스처 3종을 그대로 `curl`로 보내 202·저장·암호화를 확인**했다. 적재 응답시간 **p95 20ms**(목표 200ms). **깨진 JSON을 500 → 400으로 고쳤다** — 계약 §3-2에서 AI가 5xx를 3회 재시도하는데, 본문이 깨진 요청은 몇 번을 보내도 같은 결과라 재시도만 세 배로 늘고 원인이 "백엔드가 죽었다"로 보인다.

> **수정 기록 (2026-09-05 ⑤)** — 계약 **v1.6** 반영. **`POST /api/auth/kakao`가 액세스 토큰이 아니라 인가 코드를 받는다** — 웹에서는 앱이 토큰을 손에 쥘 수 없다(앱이 SDK 소스로 확인). `redirectUri`를 함께 받아 **등록 목록과 대조**하고, REST 키 + 클라이언트 시크릿으로 교환한다. **종전의 `app_id` 대조는 걷어냈다**(우리 키로 교환한 토큰은 정의상 우리 앱 것). `DELETE /api/account`에 **선택 본문**이 생겼다(탈퇴 시 카카오 unlink용) — 라우트는 받지만 처리는 Phase 6.

> **수정 기록 (2026-09-04 ④)** — 계약 **v1.5** 반영(AI 개정). `/internal/turns`의 `occurredAt`에 규칙이 명시됐다 — **발화 시각 · 밀리초 정밀도 · 재시도 시 동일 문자열.** 백엔드의 중복 판별 가드가 이 필드에 걸려 있어 요청했던 확인이 계약으로 못 박혔다. 엔드포인트 목록 변화 없음.
>
> **수정 기록 (2026-09-04 ③)** — 계약 **v1.4** 반영. `GET /api/trend`가 `tagGaps`·`userAvgGap`(F9-03)과 `highlights`(F9-02)를 함께 내려주게 되어 기능 ID를 갱신했다. **`GET /api/session/{id}/live`를 Phase 5 → Phase 3으로 이동** — 의존이 `turn_log`·`crisis_event`뿐이고 앱이 S02를 끝내는 데 필요하다. `GET /internal/sessions/{id}`에 `lastTurnIndex` 추가(v1.4).
>
> **수정 기록 (2026-09-03 ②)** — 받은 요청 4건 회신(api-contract v1.3)으로 §2-13·§3-4·§3-5 신설, `humeConfigId`·`livePollIntervalSec` 필드 추가가 계약에 반영됨. "제안만 된 엔드포인트" 절을 폐기하고 아래 표로 이동(구현 상태는 여전히 `미구현`).
> **수정 기록 (2026-09-03 ①)** — 문서 신설. 구현 현황 전부 `미구현`.

> 이 문서는 **실제로 무엇이 동작하는지** 보여주는 구현 현황 문서다. 계약(합의된 내용)은 [`../../docs/02-architecture/api-contract.md`](../../docs/02-architecture/api-contract.md)(**v1.5**)가 단일 출처이며, 여기서 새 필드·값을 정하지 않는다. 두 문서가 다르면 계약서가 우선한다. 갱신 규칙은 [`README.md`](README.md) "API 작업 규칙" 참조.

## 구현 현황

| 엔드포인트 | 기능 ID | Phase | 상태 |
| --- | --- | --- | --- |
| `POST /api/auth/kakao` | F1-01 | 1 | **구현 완료 (v1.6 — 인가 코드 방식)** |
| `GET /api/me` | F1-02, F2-07 | 1, 2 | **구현 완료 (v1.5 기준)** |
| `DELETE /api/account` | F1-04, F10-03 | 6 | 라우트만 — **선택 본문(v1.6)을 받지만 아직 쓰지 않는다.** 삭제·unlink는 Phase 6 |
| `POST /api/session/start` | F2-01, F3-04 | 2 | **구현 완료** — Hume 키가 자리표시라 실발급만 미검증 |
| `POST /api/session/{sessionId}/end` | F2-05 | 2 | **구현 완료** — `summary`는 항상 null (Phase 3) |
| `POST /api/session/{sessionId}/resume` (P1) | F2-07 | 2 | **구현 완료** — `resumedChatGroupId`는 항상 null (아래 §2) |
| `GET /api/session/{sessionId}/live` (v1.3) | F4-04, F11-01 | **3** | **구현 완료** |
| `GET /api/observations` | F7-06 | 5 | **구현 완료** |
| `GET /api/observations/{observationId}/evidence` | F7-07 | 5 | **구현 완료** |
| `POST /api/observations/{observationId}/feedback` (P1) | F7-08 | 5 | **구현 완료** |
| `GET /api/trend` | F9-01·02·03 (`highlights`·`tagGaps`, v1.4) | 5 | **구현 완료** |
| `GET /api/sessions` | F9-04 | 5 | **구현 완료** — 끝난 세션만 |
| `GET /api/sessions/{sessionId}` | F9-05 | 5 | **구현 완료** |
| `DELETE /api/sessions/{sessionId}` | F10-01, F10-02 | 6 | 미구현 |
| `GET /api/health` | F11-02 | 1 | **구현 완료 (v1.5 기준)** |
| `POST /internal/turns` (AI → 백엔드) | F5-01 | 3 | **구현 완료** — 고정 픽스처 3종 검증 |
| `POST /internal/observations` (백엔드 → AI) | F7-04 | 4 | **호출 구현 완료** — AI서버가 없어 지금은 관찰이 0건 |
| `GET /internal/sessions/{sessionId}` (AI → 백엔드, v1.3 · `lastTurnIndex` v1.4) | F2-03, F3-04, F5-01 | 2 | **구현 완료** — `recentObservations`는 빈 배열 (Phase 4) |
| `POST /internal/summaries` (백엔드 → AI, v1.3) | F2-05 | 3 | **호출 구현 완료** — AI서버가 없어 지금은 항상 `summary: null` |

전체 요청·응답 스키마는 계약서를 그대로 따른다. 아래 절은 **구현 후, 계약과 다르게 동작하는 부분(추가 검증, 실제로 쓰는 에러 코드 등)이 생겼을 때만** 채운다 — 계약과 동일하면 표만 갱신하고 절은 비워 둔다.

---

## 변경 이력

| 날짜 | 내용 |
| --- | --- |
| 2026-09-04 ⑤ | **Phase 1 구현** — auth/kakao · me · health 구현 완료, DELETE /api/account는 라우트만 |
| 2026-09-05 ⑧ | Phase 5 — 조회 6개. trend의 range 생략 시 500 정정. 기록 목록은 끝난 세션만 |
| 2026-09-05 ⑦ | Phase 4 — 패턴 배치·관찰 생성. `/internal/sessions`의 `recentObservations` 연결 |
| 2026-09-05 ⑥ | Phase 3 — `/internal/turns`·`/live`·요약 호출·baseline 재계산. 깨진 본문을 400으로 정정 |
| 2026-09-05 ⑤ | 계약 v1.6 — `/api/auth/kakao`가 인가 코드 방식으로. `redirectUri` 화이트리스트 검증 추가, `app_id` 대조 제거. `DELETE /api/account`에 unlink용 선택 본문 |
| 2026-09-04 ④ | 계약 v1.5 — `/internal/turns`의 `occurredAt` 규칙 명시(발화 시각·밀리초·재시도 불변). 중복 판별 가드의 전제가 계약으로 확정 |
| 2026-09-04 ③ | 계약 v1.4 — `GET /api/trend`에 `highlights`(F9-02)·`tagGaps`(F9-03) 편입, `/live`를 Phase 3으로 이동, `/internal/sessions`에 `lastTurnIndex` |
| 2026-09-03 ② | 받은 요청 4건 회신 반영 — §2-13·§3-4·§3-5 신설 3건을 구현 현황 표로 편입 |
| 2026-09-03 ① | 문서 신설. 구현 현황 전부 `미구현` |
