# Phase 5 — 조회 API (대화 중 신호 · 관찰 · 트렌드 · 기록)

> 목표: **앱의 화면 6개가 실제 데이터로 그려지는 상태**를 만든다 — S02(데모 오버레이·S07 트리거) · S03 · S03-1 · S04 · S05 · S05-1.
>
> 의존: `GET /api/session/{id}/live`는 Phase 3의 턴 로그만 필요(**Phase 4보다 먼저 붙여도 된다**). 관찰 조회는 Phase 4 필요.
>
> 근거: `spec.md` F4-04·F7-06~08·F9·F11-01 · `api-contract.md` §2-6~2-10·§2-13

## 5-1. 대화 중 턴 신호 — `GET /api/session/{sessionId}/live` (v1.3 신설)

**S02에서만 호출된다.** 앱은 `livePollIntervalSec`(2초, Phase 2에서 내려줌) 간격으로 폴링하고 화면을 벗어나면 멈춘다.

- [ ] 쿼리 `sinceTurnIndex` — 그 이후 턴만. 생략 시 세션 시작부터
- [ ] 응답 — 계약 §2-13

```json
{ "sessionId", "lastTurnIndex", "crisisDetected", "turns": [ … ] }
```

- [ ] `crisisDetected` — **세션 단위 boolean.** `crisis_event`에 그 세션 행이 있는지(`EXISTS`)
- [ ] **`demoMode == false`면 `turns`는 항상 빈 배열**
- [ ] `transcript`는 **포함하지 않는다**
- [ ] 404 `SESSION_NOT_FOUND` / 403 `FORBIDDEN`

| 규칙 | 이유 |
| --- | --- |
| `crisisDetected`는 데모 여부와 **무관하게 항상** 정상 값 | S07 위기 안내는 모든 사용자에게 떠야 한다 |
| 비데모는 `turns: []`, **`null`이 아니다** | 계약 §1-3이 `null`을 "측정하지 못했다"로 못박았다. 마스킹에 쓰면 "측정 실패"와 "볼 권한 없음"이 같은 값이 된다 |
| 새 계산·새 저장 없음 | `/internal/turns`로 이미 받은 값을 되돌려줄 뿐이다 |

> **FR-031 방어선이 여기서 이중이 된다.** 앱이 S02에 갭을 그리지 않는 것이 1차, 서버가 아예 주지 않는 것이 2차다. 앱 코드가 실수해도 그릴 데이터가 없다.
> **S07은 `false → true` 전이에서 한 번만 뜬다** — 앱 쪽 책임이지만, 서버가 세션 단위 boolean으로 주기 때문에 앱이 전이를 판단할 수 있다(TC-27).

## 5-2. 관찰 목록 — `GET /api/observations` (F7-06)

- [ ] 최신순, 페이징(`limit` 기본 20 / 최대 100) — 계약 §1-4·§2-6
- [ ] `[{ observationId, createdAt, sentence, evidence }]`, `evidence`는 숫자 4개
- [ ] **관찰이 없으면 빈 배열** — 계약 §1-3. "아직 없어요" 안내는 앱이 하고 **억지 문구를 서버가 만들지 않는다**
- [ ] `status = 'invalidated'`인 관찰은 조회에서 제외

## 5-3. 관찰 근거 — `GET /api/observations/{id}/evidence` (F7-07)

- [ ] 근거 turn의 **발화 텍스트·시각·갭** 반환 — 계약 §2-7
- [ ] `transcript`는 **복호화해서** 내려간다 (Phase 3의 변환기가 자동 처리)
- [ ] 근거 turn이 삭제된 관찰은 Phase 6의 연쇄 무효화로 이미 조회되지 않는다

> **P0인 이유** — 이게 없으면 §1.4의 "evidence 불일치 0건"을 **증명할 수단이 사라진다.** 신뢰 서사의 마지막 고리라 스코프 컷에서도 자르지 않는다(spec §11).

## 5-4. 관찰 피드백 — `POST /api/observations/{id}/feedback` (F7-08, **P1**)

- [ ] 관찰당 **1회**, `agree` / `disagree` 둘만 — 계약 §2-7-1
- [ ] **`disagree`가 관찰을 삭제하지 않는다.** `observation.feedback`에 표시만
- [ ] 이유 입력·취소는 제공하지 않는다

> **왜 삭제하지 않는가** — 사용자가 부정해도 우리가 계산한 숫자가 틀린 것은 아니고 evidence는 유효하다. 삭제하면 §1.4 "evidence 불일치 0건"의 판정 대상이 사라져 지표가 왜곡된다.

## 5-5. 감정 추세 — `GET /api/trend` (F9-01·02·03)

- [ ] `range=7d|30d|90d` — 계약 §2-8
- [ ] 일자별 `{ date, textValenceAvg, voiceValenceAvg, gapAvg }`
- [ ] **일자 집계는 KST 기준**(계약 §1-1) — 저장은 UTC이므로 변환이 필요하다
- [ ] **데이터 없는 날은 배열에서 아예 생략**한다. 0으로 채우거나 보간하지 않는다
- [ ] 태그별 갭 비교(F9-03, P1)는 **등장 3회 미만 태그 제외** — F7-03과 같은 기준

> **없는 감정을 그리지 않는다**(계약 §1-3). 앱은 생략된 날에서 선을 끊는다. 서버가 0을 채우면 "그날 감정이 0이었다"는 거짓이 된다.
> **일자 경계가 KST인 이유** — 사용자가 체감하는 "하루"가 기준이어야 트렌드가 맞다. 새벽 1시 대화는 그 전날의 하루에 속한다고 느껴진다.

## 5-6. 대화 기록 — `GET /api/sessions` · `GET /api/sessions/{id}` (F9-04·05)

- [ ] 목록: `[{ sessionId, startedAt, durationSec, turnCount, summary, gapAvg }]` + `total` — 계약 §2-9
- [ ] `tags`는 그 세션 상위 3개까지
- [ ] 상세: 턴별 `{ turnId, turnIndex, occurredAt, role, transcript, textValence, voiceValence, gap, gapTriggered, tags }` — 계약 §2-10
- [ ] **assistant 턴은 valence·gap이 전부 `null`** — 저장된 그대로

> **갭 수치가 여기서는 노출된다.** 대화 화면(S02)과 구분되는 지점이다(FR-031). 기록·트렌드는 돌아보는 화면이라 수치가 관찰당하는 느낌을 주지 않는다.

## 완료 기준

- 앱의 S02 데모 오버레이·S07 시트가 목업이 아닌 실제 데이터로 동작한다
- **TC-26** — `demoMode == false` 계정의 `/live` 응답에서 `turns`가 **빈 배열**이고 `crisisDetected`는 정상 값이다
- **TC-27** — 위기 감지 후 연속 폴링에서 S07이 **1회만** 표시된다
- **TC-18** — 트렌드에 두 선이 그려지고 데이터 없는 날은 선이 끊긴다
- **TC-17** — 관찰 카드에서 근거 대화 N건을 전부 열람할 수 있고 숫자가 일치한다
- **TC-23** — `아니에요` 선택 후에도 관찰·evidence가 유지된다 (P1)
- 관찰이 0건인 사용자에게 빈 배열이 내려간다 (오류가 아니다)
- `api-spec.md` 구현 현황 갱신 (조회 7개)

## 이 Phase에서 하지 않는 것

- **삭제** (`DELETE /api/sessions/{id}`) — Phase 6
- **관찰 생성·배치** — Phase 4
- **데모 모드 플래그를 켜는 운영 기능** — Phase 7. 여기서는 플래그를 **읽어서 분기만** 한다
- 앱의 화면 구현 — 앱 담당
