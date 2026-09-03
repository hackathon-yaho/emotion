# API 구현 현황 — 백엔드

> **수정 기록 (2026-09-03 ②)** — 받은 요청 4건 회신(api-contract v1.3)으로 §2-13·§3-4·§3-5 신설, `humeConfigId`·`livePollIntervalSec` 필드 추가가 계약에 반영됨. "제안만 된 엔드포인트" 절을 폐기하고 아래 표로 이동(구현 상태는 여전히 `미구현`).
> **수정 기록 (2026-09-03 ①)** — 문서 신설. 구현 현황 전부 `미구현`.

> 이 문서는 **실제로 무엇이 동작하는지** 보여주는 구현 현황 문서다. 계약(합의된 내용)은 [`../../docs/02-architecture/api-contract.md`](../../docs/02-architecture/api-contract.md)(v1.3)가 단일 출처이며, 여기서 새 필드·값을 정하지 않는다. 두 문서가 다르면 계약서가 우선한다. 갱신 규칙은 [`README.md`](README.md) "API 작업 규칙" 참조.

## 구현 현황

| 엔드포인트 | 기능 ID | Phase | 상태 |
| --- | --- | --- | --- |
| `POST /api/auth/kakao` | F1-01 | 1 | 미구현 |
| `GET /api/me` | F1-02, F2-07 | 1, 2 | 미구현 |
| `DELETE /api/account` | F1-04, F10-03 | 6 | 미구현 |
| `POST /api/session/start` | F2-01, F3-04 | 2 | 미구현 |
| `POST /api/session/{sessionId}/end` | F2-05 | 2 | 미구현 |
| `POST /api/session/{sessionId}/resume` (P1) | F2-07 | 2 | 미구현 |
| `GET /api/session/{sessionId}/live` (v1.3) | F4-04, F11-01 | 5 | 미구현 |
| `GET /api/observations` | F7-06 | 5 | 미구현 |
| `GET /api/observations/{observationId}/evidence` | F7-07 | 5 | 미구현 |
| `POST /api/observations/{observationId}/feedback` (P1) | F7-08 | 5 | 미구현 |
| `GET /api/trend` | F9-01~03 | 5 | 미구현 |
| `GET /api/sessions` | F9-04 | 5 | 미구현 |
| `GET /api/sessions/{sessionId}` | F9-05 | 5 | 미구현 |
| `DELETE /api/sessions/{sessionId}` | F10-01, F10-02 | 6 | 미구현 |
| `GET /api/health` | F11-02 | 1 | 미구현 |
| `POST /internal/turns` (AI → 백엔드) | F5-01 | 3 | 미구현 |
| `POST /internal/observations` (백엔드 → AI) | F7-04 | 4 | 미구현 |
| `GET /internal/sessions/{sessionId}` (AI → 백엔드, v1.3) | F2-03, F3-04 | 2 | 미구현 |
| `POST /internal/summaries` (백엔드 → AI, v1.3) | F2-05 | 2 | 미구현 |

전체 요청·응답 스키마는 계약서를 그대로 따른다. 아래 절은 **구현 후, 계약과 다르게 동작하는 부분(추가 검증, 실제로 쓰는 에러 코드 등)이 생겼을 때만** 채운다 — 계약과 동일하면 표만 갱신하고 절은 비워 둔다.

---

## 변경 이력

| 날짜 | 내용 |
| --- | --- |
| 2026-09-03 ② | 받은 요청 4건 회신 반영 — §2-13·§3-4·§3-5 신설 3건을 구현 현황 표로 편입 |
| 2026-09-03 ① | 문서 신설. 구현 현황 전부 `미구현` |
