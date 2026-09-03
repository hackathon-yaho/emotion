# Phase 5 — 조회 API (관찰 · 트렌드 · 대화기록)

의존: Phase 4(관찰)가 있어야 F7-06~08이 의미 있다. F9(트렌드·기록)는 Phase 3의 턴 로그만 있으면 됨 — 먼저 착수해도 무방. `GET /api/session/{id}/live`는 Phase 3의 턴 로그만 필요하다(관찰 불필요) — Phase 4보다 먼저 붙여도 된다.

## 체크리스트

- [ ] `GET /api/observations` — 최신순 목록 — 근거: spec F7-06, api-contract §2-6
- [ ] `GET /api/observations/{id}/evidence` — 근거 turn의 발화 텍스트·시각·갭 반환. 근거 turn이 삭제된 경우 해당 관찰은 이미 Phase 6의 연쇄 무효화로 조회되지 않아야 함 — 근거: spec F7-07, api-contract §2-7
- [ ] `POST /api/observations/{id}/feedback` (P1) — 관찰당 1회, `agree`/`disagree`만. **`disagree`가 관찰을 삭제하지 않는다**(표시만 저장) — 근거: spec F7-08, api-contract §2-7-1
- [ ] `GET /api/trend?range=30d` — 일자별 `{ date, textValenceAvg, voiceValenceAvg, gapAvg }`, KST 기준 일자 집계, 데이터 없는 날은 배열에서 생략(보간 금지) — 근거: spec F9-01·02, api-contract §2-8
- [ ] `GET /api/sessions` — 목록, 페이징(limit 기본 20/최대 100) — 근거: spec F9-04, api-contract §2-9
- [ ] `GET /api/sessions/{id}` — 턴별 상세(`transcript`, `textValence`, `voiceValence`, `gap`, `tags`). **여기서는 갭 수치가 노출된다** (대화 화면과 다름) — 근거: spec F9-05, api-contract §2-10
- [ ] `GET /api/session/{sessionId}/live` (§2-13, v1.3) — `sinceTurnIndex` 이후 턴을 `/internal/turns`로 이미 받은 값 그대로 반환(새 계산 없음). **`demoMode == false`면 `turns: []`**(`null` 아님 — §1-3 규칙과 충돌 방지), `crisisDetected`는 데모 여부 무관하게 항상 정상 값. `transcript` 필드 없음 — 근거: spec F4-04, F11-01, api-contract §2-13

## 결정 완료 (2026-09-03 회신 반영)

`live` 엔드포인트는 **폴링**(SSE 아님)으로 확정 — `/internal/turns`가 fire-and-forget이라 SSE로도 원천 유실은 못 덮고, 폴링은 늦게 도착한 턴을 다음 주기에 회수한다. 간격(2초)은 `session/start` 응답의 `livePollIntervalSec`(Phase 2)로 내려준다. 상세는 `README.md` 결정 로그와 `response/app/live-turn-signal.md` 참조.

## 완료 기준

- TC-18 (트렌드 조회: 두 선 표시, 데이터 없는 날 선 끊김)
- TC-23 (관찰 카드 `아니에요` 선택 → 표시만 남고 관찰·evidence는 유지됨)
- TC-26 (`demoMode == false`에서 `live` 호출 시 `turns` 빈 배열)
- TC-27 (위기 감지 후 연속 폴링에서 S07이 1회만 표시)
