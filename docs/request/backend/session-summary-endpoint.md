# 세션 요약 생성 경로 요청 — F2-05의 `summary`를 누가 만드는지 계약에 없습니다

> **상태: ⏳ 회신 대기** (요청 2026-09-03)
> 회신은 `../../response/ai/session-summary-endpoint.md`에 들어옵니다.
> **막고 있는 작업**: `POST /api/session/{id}/end` 응답의 `summary`(S02-1 종료 요약, S05 목록). 계약이 `summary: null`을 허용하므로 **다른 작업은 막히지 않습니다.** 9/10 도그푸딩에 요약이 없어도 데이터는 쌓입니다.

- 요청자: AI
- 대상: 백엔드
- 관련 문서: `../../02-architecture/api-contract.md` §2-5·§3-3 / `../../00-context/spec.md` F2-05 / `../../00-context/prd.md` §6·§9

---

## 배경

spec F2-05는 "④ 요약 문장 생성"을 담당 **A/B**로 두고, 계약서 §2-5는 `summary`를 응답에 넣되 null을 허용합니다. 그런데 **AI서버에 요약을 요청하는 내부 엔드포인트가 계약에 없습니다.** §3에 있는 AI서버 관련 경로는 `/internal/turns`(적재)와 `/internal/observations`(문장화)뿐입니다.

PRD §6 다이어그램은 LLM 호출 지점을 AI서버 하나로 그리고 있습니다. 백엔드가 직접 LLM을 부르면 금칙어 검사·로깅 정책(FR-092)·모델 설정이 두 곳에 생깁니다.

## 제안 — `POST /internal/summaries` (백엔드 → AI서버)

`/internal/observations`와 같은 방향·같은 인증입니다.

**백엔드 → AI서버 요청**

```json
{
  "sessionId": "sess_…",
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
| 입력 | 턴 텍스트만. valence·갭·태그는 보내지 않습니다 (요약에 수치가 섞이면 S02-1이 갭을 노출하는 셈이 됩니다 — FR-031 취지) |
| 출력 | 한 문장, 존댓말, **감정 단정 없음**("힘든 하루였네요" 금지 — "~에 대해 이야기했습니다" 형식). 진단·조언 없음 |
| 호출 시점 | `POST /api/session/{id}/end` 처리 중 **동기 호출, 타임아웃 3초.** 실패·타임아웃이면 `summary: null`로 응답 (계약 §2-5가 이미 허용) |
| 실패 | AI서버가 `422 SUMMARY_REJECTED`(사후 검사 실패) 또는 5xx. 백엔드는 재시도하지 않고 null |
| 사후 검사 | AI서버가 금칙어(진단·약물·치료)·2문장 이상·수치 포함을 검사해 실패 시 422 |

## 대안 — 백엔드가 직접 LLM 호출

가능합니다. 다만 ① LLM 키·모델 설정이 두 서비스에 생기고 ② 금칙어 검사 로직이 중복되며 ③ PRD §6 "LLM 호출 지점 1개"와 어긋납니다. 3초 타임아웃 동기 호출이 부담스러우면 **`end` 응답은 `summary: null`로 먼저 주고 AI서버가 비동기로 만들어 `PATCH /internal/sessions/{id}/summary`로 돌려주는 방식**도 있습니다 — 이 경우 S02-1은 요약 없이 뜨고 S05 목록에서만 보이게 됩니다. 어느 쪽이든 맞추겠습니다.

## 결정을 요청하는 것

1. `POST /internal/summaries` 신설(동기)에 동의하는지, 아니면 대안 중 무엇으로 갈지.
2. 경로·필드명 확정.
3. 타임아웃 값 (제안 3초).

## 채택 시 고칠 위치

| 문서 | 위치 | 변경 |
| --- | --- | --- |
| api-contract.md | §3 **신규 3-5** | 엔드포인트 정의 |
| api-contract.md | §2-5 | `summary` 생성 경로·타임아웃 각주 |
| api-contract.md | §6 변경 이력 | 다음 버전 |
| spec.md | F2-05 처리 ④ | "AI서버 `/internal/summaries` 호출, 실패 시 null" 명시 |
| ai-pipeline.md | §8.2 | 확정 반영 (AI가 수정) |
| ai-server/prompts/summary.system.md | 신규 | 프롬프트 (AI) |
