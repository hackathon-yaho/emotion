# 통합 1·2번을 로컬에서 먼저 돌렸습니다 — 결함 2건이 나왔습니다

> **상태: ✅ 회신 완료 (2026-09-05) — 결함 2건 모두 조치**
> 회신: [`../../response/backend/integration-round-1.md`](../../response/backend/integration-round-1.md)
> 요약 — ① 500은 **요청서보다 먼저 고쳐져 있었습니다**(`43c97be`). 같은 실수가 `session.py`에도 있어 같이 고쳤고, 401 경로 3종을 종단 테스트로 고정했습니다 ② `sessionId` 로그는 **지적이 맞습니다.** `sessionRef` = `SHA-256[:8]`로 바꾸고, 이름이 무엇이든 거부하도록 화이트리스트를 고쳤습니다. 실행 로그에서 원본 0건 확인 ③ 포트 8100 맞습니다. **⚠️ LLM 벤더가 OpenAI로 바뀌어 `ANTHROPIC_API_KEY`가 아니라 `OPENAI_API_KEY`입니다.**
>
> <sub>원래 배너</sub>
> **막고 있는 작업**: 없습니다. **다만 아래 1번은 위기 상황에서 fail-closed가 깨지는 경로**라 우선순위가 높습니다.

- 요청자: 백엔드
- 대상: AI
- 관련 문서: `../../02-architecture/api-contract.md` §1-1·§3-1·§3-2·§3-4·§4 · `../../response/backend/hume-account-setup.md`

---

## 무엇을 했나 — 터널 대신 **양쪽을 제 로컬에서** 띄웠습니다

터널을 열면 제 로컬이 외부에 노출되고 양쪽이 동시에 붙어 있어야 합니다. **그럴 필요가 없었습니다** — `ai-server/`가 같은 저장소에 있어서 제가 그대로 띄웠습니다.

```
백엔드   localhost:8080   (Spring Boot)
AI서버   localhost:8100   (uvicorn, ai-server/.venv)
```

`ANTHROPIC_API_KEY`는 없는 상태입니다. **그래서 LLM 경로는 전부 실패하는데, 오히려 그게 degraded 경로를 실측하게 해줬습니다.**

## ✅ 잘 된 것 — 통합 1·2번이 실제로 돕니다

Hume 흉내로 `POST /chat/completions?custom_session_id={실제 세션}`을 쐈습니다.

| 확인 | 결과 |
| --- | --- |
| AI → 백엔드 `GET /internal/sessions` (CLM 인증) | ✅ 200 |
| CLM 응답 | ✅ **200 SSE**, `system_fingerprint`에 sessionId 반영 (계약 §4) |
| AI → 백엔드 `POST /internal/turns` | ✅ **user·assistant 2건 적재** |
| 프로소디 → `voiceValence` | ✅ **−0.81** — 규칙 계층이 실제로 계산했습니다 |
| 분석 실패 시 degraded | ✅ `textValence: null` · `gap: null` — 계약 §1-3·TC-06 그대로 |
| 백엔드 → AI `POST /internal/summaries` | ✅ 본문 수용, `422 SUMMARY_REJECTED(call_failed)` — **키가 없어서**이고 계약 §3-5의 실패 처리 그대로입니다. 백엔드는 재시도 없이 `summary: null` |
| 백엔드 → AI `POST /internal/observations` | ✅ 본문 수용, `422 SENTENCE_REJECTED(call_failed)` — 같은 이유 |
| 시크릿 없이 `/internal/observations` | ✅ 401 |
| **백엔드를 내리고 CLM 요청** | ✅ **CLM은 200으로 끝났습니다** — fire-and-forget이 성립합니다(spec F5-04). 그 턴은 재시도 후 유실됐고, 그게 설계대로입니다 |

**`ANTHROPIC_API_KEY` 하나만 꽂으면 나머지가 다 열립니다.** 지금 막힌 것은 전부 그 한 줄입니다.

---

## ⚠️ 1. fail-closed 경로가 500으로 터집니다 (우선순위 높음)

**세션 조회가 실패하면 401을 Hume에 돌려주도록 돼 있는데, 그 경로에서 예외가 납니다.**

```
File "ai-server/app/main.py", line 90, in chat_completions
    error_log("clm_unauthorized", sid=custom_session_id, reason=exc.reason)
TypeError: error_log() got multiple values for argument 'reason'
```

`error_log`의 두 번째 위치 인자가 이미 `reason`인데 키워드로 한 번 더 넘어가는 것으로 보입니다.

**왜 중요한가** — 이 경로는 **모르는 세션·`ended` 세션·조회 실패**에서 타는 유일한 방어선입니다(계약 §4). 지금은 401 대신 **500**이 나가고, Hume 입장에서 그 둘은 다른 사건입니다. **정상 경로에서는 절대 안 밟히는 코드라** 통합 전까지 드러나지 않았습니다.

**재현**: 없는 `custom_session_id`로 `POST /chat/completions` — 저는 두 번 다 500을 받았습니다.

## ⚠️ 2. 로그에 `sessionId`가 평문으로 남습니다 (절대 원칙)

제 30분짜리 실행 로그에서 **7건** 나왔습니다.

```json
{"event": "error", "reason": "session_refetch_failed:lookup_connect_failed", "sid": "1ff569a3-5336-471a-bd22-d17b09a3e88d"}
{"event": "turn", "sid": "1ff569a3-...", "gap": null, ...}
```

계약 §1-1이 이렇게 못 박고 있습니다.

> `sessionId` — **UUIDv4, 접두사 없음.** §4 CLM 인증에 `custom_session_id`로 쓰이는 값이라 **로그에 남기지 않는다** — 비밀과 동급으로 취급

**이 값이 곧 CLM 인증 수단**이라, 로그를 보는 사람은 그 세션인 척 CLM을 부를 수 있습니다.

**백엔드는 `sessionRef`를 씁니다** — `SHA-256(sessionId)[:8]`. 원본을 복원할 수 없으면서 같은 세션의 로그·오류를 묶는 데는 충분합니다(`backend/docs/data-model.md`). 같은 방식을 권합니다. 백엔드 로그에서는 같은 시간대에 sessionId가 **0건**입니다.

> 필드 화이트리스트로 강제한다고 `.env.example`에 적어두셨는데, `sid`가 그 화이트리스트에 들어 있는 것으로 보입니다.

---

## 알려드리는 것 — 제 쪽에서 고친 것 1건

**AI서버 포트를 8000으로 잘못 알고 있었습니다.** `ai-server/.env.example`의 `AI_PORT=8100`이 맞고, 백엔드의 `AI_SERVER_BASE_URL` 기본값을 **8100으로 고쳤습니다.** 계약에 포트 규정이 없어 그쪽 `.env.example`을 출처로 삼았습니다 — 다르면 알려주세요.

## 아직 못 본 것

- **재시도 후 중복 판별의 실동작** — 제안하신 "저장은 성공시키고 응답만 버리기"는 **고장 주입점이 있어야** 됩니다. 백엔드를 내려서 재시도가 도는 것(그리고 3회 후 포기)까지는 봤지만, **저장 성공 + 응답 유실**은 못 만들었습니다. 백엔드 가드 자체는 단위·통합 테스트로 고정돼 있고 실서버에서도 확인했습니다(같은 `occurredAt` → 행 1개, 다른 `occurredAt` → 행 2개 + `TURN_INDEX_COLLISION`)
- **Hume 실연결** — Config가 없어서입니다

## 회신 부탁드립니다

1. **1번(500) 수정 여부·시점** — 위기 상황의 방어선이라 우선입니다
2. **2번(sessionId 로그) 조치 방향** — `sessionRef` 방식으로 가시겠습니까?
3. 8100 포트가 맞는지

**`ai-server/`에는 아무것도 고치지 않았습니다.** 로컬 실행용 `.env`만 만들었고(`.gitignore` 대상), `.venv/`가 생겼습니다.
