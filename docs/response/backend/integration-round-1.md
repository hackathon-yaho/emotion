# 회신 — 통합 1·2번 결함 2건

- 원본 요청: [`../../request/ai/integration-round-1.md`](../../request/ai/integration-round-1.md) (백엔드 → AI, 2026-09-05)
- 회신자: AI
- 회신일: 2026-09-05
- 반영된 문서: `ai-server/app/telemetry.py` · `02-architecture/ai-pipeline.md` §10

---

## 결론

| 결함 | 상태 |
| --- | --- |
| 1. fail-closed 경로 500 | **이미 고쳐서 푸시돼 있습니다** (`43c97be`, 요청서보다 앞섭니다). 지금 코드는 401을 냅니다 |
| 2. 로그에 `sessionId` 평문 | **맞습니다. 고쳤습니다.** `sessionRef` = `SHA-256(sessionId)[:8]`, 백엔드와 같은 방식 |
| 3. 포트 8100 | **맞습니다** |

**터널 대신 양쪽을 로컬에서 띄우신 판단이 옳았습니다.** 제가 회신에서 "로컬 합체는 검증 대상을 없앤다"고 했는데, 그건 네트워크 실패 모드에 대한 말이었고 **배선 검증에는 그쪽이 빠르고 정확합니다.** 실제로 제가 못 잡은 것을 잡으셨습니다.

---

## 1. 500 — 요청서보다 먼저 고쳐져 있었습니다

**같은 버그를 같은 날 종단 테스트로 잡았습니다.** 커밋 `43c97be`입니다.

```python
# 고치기 전 — error_log(reason, **fields) 의 reason 이 겹친다
error_log("clm_unauthorized", sid=custom_session_id, reason=exc.reason)

# 고친 뒤
error_log(f"clm_unauthorized:{exc.reason}", sessionRef=session_ref(custom_session_id))
```

진단하신 원인이 정확합니다. **같은 실수가 `session.py`에도 있었고** 거기도 같이 고쳤습니다.

**다시 안 나게 한 방법**은 테스트입니다. `tests/test_e2e.py`가 세 경로를 검사합니다.

| 검사 | 기대 |
| --- | --- |
| 없는 `custom_session_id` | 401 |
| `status: "ended"` 세션 | 401 |
| `custom_session_id` 없음 | 401 |

**정상 경로에서는 절대 안 밟히는 코드라 통합 전까지 안 드러났다**는 지적이 이 문제의 핵심이었습니다. 그래서 그 경로들만 따로 도는 테스트를 만들었습니다.

지금 코드로 다시 한 번 쏴 보시고 여전히 500이면 알려주세요. 그때는 다른 원인입니다.

## 2. `sessionId` 로그 — 지적이 맞습니다. 고쳤습니다

**변명의 여지가 없습니다.** 계약 §1-1이 "비밀과 동급"이라고 못 박아 뒀는데, 제가 만든 화이트리스트에 `sid`를 넣어 뒀습니다. **화이트리스트가 오히려 유출을 승인한 꼴**입니다.

**`sessionRef`로 바꿨습니다.** 제안하신 방식 그대로입니다.

```python
def session_ref(session_id: str | None) -> str:
    """SHA-256(sessionId)[:8]. 백엔드의 sessionRef와 같은 방식이라 양쪽 로그를 맞춰 볼 수 있다."""
```

```json
{"event": "error", "reason": "clm_unauthorized:session_not_found", "sessionRef": "a3a9e1ed"}
{"event": "turn", "sessionRef": "a3a9e1ed", "gap": null, "voiceValence": -0.84, ...}
```

**같은 실수가 반복되지 않게 한 걸음 더 갔습니다.** `sid`를 빼는 것만으로는 다음에 `sessionId=`로 넘기면 다시 샙니다. 그래서 **이름이 무엇이든 거부**합니다.

```python
NEVER = frozenset({
    "transcript", "text", "content", "sentence", "summary", "message", "prompt", "tags",
    "sid", "sessionId", "session_id", "customSessionId", "custom_session_id",
})
```

테스트가 다섯 이름을 전부 시도해 **출력에 원본이 없는지** 검사합니다. 종단 테스트 실행 로그에서 원본 UUID **0건**을 확인했습니다.

## 3. 포트 8100이 맞습니다

`ai-server/.env.example`의 `AI_PORT=8100`이 출처가 맞습니다. 계약에 로컬 포트 규정이 없는 것도 맞고, 그쪽 `AI_SERVER_BASE_URL` 기본값을 8100으로 고치신 것도 맞습니다.

---

## ⚠️ 알려드릴 것 — LLM 벤더가 바뀌었습니다

**`ANTHROPIC_API_KEY`가 아니라 `OPENAI_API_KEY`입니다.** 팀 결정으로 2026-09-05에 교체했습니다(PRD §14-8, `ai-pipeline.md` AI-20).

| | 이전 | 지금 |
| --- | --- | --- |
| 환경변수 | `ANTHROPIC_API_KEY` | **`OPENAI_API_KEY`** |
| 분석 | `claude-haiku-4-5` | `gpt-5.6-luna` |
| 응답 | `claude-sonnet-5` | `gpt-5.6-terra` |
| 관찰 | `claude-opus-5` | `gpt-5.6-sol` |
| 요약 | `claude-haiku-4-5` | `gpt-5.6-luna` |

**`backend/docs/blocked.md`와 `phase-4-pattern-batch.md`에 `ANTHROPIC_API_KEY`로 적혀 있습니다.** 그쪽 폴더라 제가 고치지 않았습니다.

**설계·계약·프롬프트·가드는 하나도 안 바뀌었습니다.** 고친 범위는 `app/llm/` 4개 파일과 환경변수뿐입니다 — LLM 호출을 한 계층에 가둬 둔 경계가 실제로 값을 했습니다. 그쪽에서 보시는 동작(`422 SENTENCE_REJECTED`·`SUMMARY_REJECTED`, degraded 경로)은 전부 그대로입니다.

## 아직 못 본 것 — 중복 판별 실동작을 만드는 방법

"저장은 성공시키고 응답만 버리기"는 고장 주입점이 필요하다고 하셨는데, **제 쪽 `.env` 하나로 만들 수 있습니다.**

`BACKEND_BASE_URL`을 **응답을 삼키는 프록시**로 돌리면 됩니다. 백엔드 앞에 얇은 프록시를 두고, 요청은 그대로 넘기되 응답을 반환하기 전에 끊습니다. AI서버 입장에서는 타임아웃이라 재시도하고, 백엔드는 같은 턴을 두 번 받습니다.

```
AI서버 → 프록시(요청 전달, 응답 폐기) → 백엔드
```

**개발용 우회 스위치를 코드에 넣지 않는 이유**는 이전 회신(AI-18)과 같습니다 — 그런 스위치는 배포까지 따라갑니다. 프록시는 외부 장치라 저장소에 남지 않습니다.

원하시면 제가 프록시 스크립트를 `ai-server/eval/`에 두겠습니다. 필요하시면 알려주세요.

## 요청자 후속 작업

- **`backend/docs/`의 `ANTHROPIC_API_KEY` 표기를 `OPENAI_API_KEY`로** 정정 부탁드립니다
- 고친 코드로 **없는 세션 요청을 한 번만 다시** 쏴 주세요 — 401이 나오는지 확인하고 싶습니다
- 나머지는 없습니다. 키가 들어오면 LLM 경로가 열립니다
