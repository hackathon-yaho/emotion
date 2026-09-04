# fixtures/internal — 내부 API 고정 JSON

**백엔드와 AI서버가 같은 파일로 검증합니다.** 터널을 열기 전에 각자 `curl`과 목으로 확인할 수 있고, 붙인 뒤에는 "제 쪽에선 되는데요"가 나올 여지가 없습니다.

- 근거 계약: [`../../../../docs/02-architecture/api-contract.md`](../../../../docs/02-architecture/api-contract.md) §3 (**v1.5**)
- 협의 문서: [`../../../../docs/response/backend/integration-test-path.md`](../../../../docs/response/backend/integration-test-path.md)
- **계약이 바뀌면 이 파일들도 같은 작업 안에서 고칩니다.** 어긋나면 계약이 맞습니다.

## 파일

| 파일 | 방향 | 계약 |
| --- | --- | --- |
| `sessions.200.open.json` | 백엔드 → AI서버 (응답) | §3-4 — 정상 세션 |
| `sessions.200.ended.json` | 백엔드 → AI서버 (응답) | §3-4 — 종료된 세션. **AI서버는 이걸 받으면 Hume에 401을 준다** |
| `sessions.200.resumed.json` | 백엔드 → AI서버 (응답) | §3-4 — 이어하기 세션. `lastTurnIndex`가 0이 아니다 |
| `turns.user.request.json` | AI서버 → 백엔드 (요청) | §3-2 — user 턴 |
| `turns.assistant.request.json` | AI서버 → 백엔드 (요청) | §3-2 — assistant 턴. valence·gap·tags가 전부 null/빈 배열 |
| `turns.user.degraded.request.json` | AI서버 → 백엔드 (요청) | §3-2 — 분석 호출이 실패했을 때. `textValence`·`gap`이 null이고 `gapTriggered`는 false |
| `summaries.request.json` / `summaries.200.json` | 백엔드 → AI서버 | §3-5 |
| `observations.request.json` / `observations.200.json` | 백엔드 → AI서버 | §3-3 |

## 검증할 때 특히 볼 것

**`sessions.200.ended.json`** — 200으로 오지만 AI서버가 **401로 바꿔서** Hume에 돌려줍니다(§3-4, `ai-pipeline.md` §7.1). 백엔드가 이걸 401로 주지 않는 것이 맞고, AI서버가 그대로 통과시키는 것은 틀립니다.

**`turns.user.request.json`의 `occurredAt`** — 밀리초 정밀도이고 **재시도에서 같은 값**입니다(§3-2 v1.5). 백엔드의 중복 판별이 이 필드에 걸려 있습니다. 재시도 시나리오를 만들어 볼 때 이 파일을 **그대로 두 번** 보내면 두 번째는 202 "이미 적재됨"이어야 합니다.

**`turns.assistant.request.json`** — `textValence`·`voiceValence`·`gap`·`gapTriggered`·`tags`·`topProsody`·`crisis`가 전부 비어 있습니다. assistant 턴에 valence를 실으면 계약 위반입니다.

**`turns.user.degraded.request.json`** — 분석 호출이 400ms를 넘겨도 **대화는 계속되고 턴은 적재됩니다**(FR-024). 이 경우가 실패가 아니라 정상 경로라는 것을 양쪽이 같이 확인해야 합니다.

## 붙이는 순서 (협의됨)

1. `GET /internal/sessions/{id}` — 200 open · 200 ended · 404 · 타임아웃
2. `POST /internal/turns` — user · assistant · **같은 파일 재전송(중복 판정)**
3. `POST /internal/summaries`
4. `POST /internal/observations`

1번이 먼저인 이유는 CLM 인증을 겸해서입니다. 이게 안 서면 나머지가 전부 401로 막혀 검증이 성립하지 않습니다.
