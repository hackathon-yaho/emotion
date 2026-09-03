# 세션 컨텍스트 내부 조회 엔드포인트 요청 — AI서버가 임계값·모드를 알 경로가 없습니다

> **상태: ✅ 회신 완료** (2026-09-03)
> 회신: [`../../response/ai/session-context-lookup.md`](../../response/ai/session-context-lookup.md) — 계약 v1.3 §3-4·§4 반영
> **막고 있는 작업**: `/internal/turns`의 `thresholdMode`·`gapTriggered` 정확성, 5분 마무리 유도(F2-03 B측), CLM 인증. **회신 전에도 AI서버 개발은 진행합니다** — `.env` 고정 임계값으로 동작하게 만들어두고 필드가 생기면 교체합니다. 9/10 도그푸딩은 고정 임계값으로도 성립합니다.

- 요청자: AI
- 대상: 백엔드
- 관련 문서: `../../02-architecture/api-contract.md` §2-4·§3-2·§4 / `../../02-architecture/ai-pipeline.md` §2.1·§7 / `../../00-context/spec.md` F2-03·F3-04 / `../../00-context/prd.md` FR-013·FR-023

---

## 배경 — Hume은 `custom_session_id`만 줍니다

AI서버가 Hume에게서 받는 것은 `POST /chat/completions?custom_session_id={sid}`와 `messages[]`(전사·프로소디)가 전부입니다(계약서 §4). 그런데 AI서버가 해야 하는 일 중 다음은 **세션에 대한 정보 없이는 할 수 없습니다.**

| 필요한 것 | 왜 | 지금 계약에 있는 곳 |
| --- | --- | --- |
| `thresholdMode`, `gapThreshold` | 갭 트리거 판정(F3-03), `/internal/turns`에 `thresholdMode`를 실어야 함(§3-2) | `POST /api/session/start` 응답으로 **앱에만** 내려감 |
| `startedAt`(또는 `usedSec`), `softWrapSec` | 5분 마무리 유도 지시 주입(F2-03 처리 ①, 담당 B/C) | 앱만 앎 |
| 세션이 실제로 존재·진행 중인지 | **CLM 인증** — 아래 |
| `demoMode` | 로깅 상세도 (필수 아님) | 앱만 앎 |

Hume `messages[].time`으로 경과 시간을 근사할 수는 있지만, 이어하기(F2-07)로 chat group이 이어지면 기준점이 흔들려 `usedSec` 승계와 어긋납니다.

## CLM 인증 문제 — 이 조회를 인증으로도 쓰고 싶습니다

Hume CLM의 인증 수단은 `session_settings.language_model_api_key`입니다. 앱이 이 값을 WebSocket으로 보내면 Hume이 우리 CLM에 `Authorization: Bearer <값>`으로 전달합니다. **즉 앱이 비밀을 들고 있어야 하고, 웹 배포라 번들에 그대로 노출됩니다.** FR-013·NFR-04가 Hume 키에 대해 막은 것과 같은 문제가 CLM 키에서 생깁니다.

대안: **`custom_session_id`를 백엔드 세션 조회로 검증**합니다. 모르는 ID면 401. 앱에 비밀이 없고, 세션이 끝나면 자동으로 무효화됩니다. 단 이러려면 **`sessionId`가 추측 불가능해야** 합니다 — 계약서 예시 `sess_9c1d4e`(6자)는 24비트라 부족합니다.

## 제안 — `GET /internal/sessions/{sessionId}`

경로·필드명은 스케치이고 확정은 백엔드 몫입니다.

```json
{
  "sessionId": "sess_…",
  "status": "open",
  "startedAt": "2026-09-18T12:30:00Z",
  "usedSec": 0,
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "softWrapSec": 300,
  "hardCutSec": 420,
  "demoMode": false,
  "recentObservations": [
    { "observationId": "obs_014", "tag": "회의", "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요." }
  ]
}
```

| 항목 | 제안 |
| --- | --- |
| 인증 | 기존 `X-Internal-Secret` (§3-1) |
| `status` | `"open"` \| `"ended"`. `ended`면 AI서버는 401을 Hume에 돌려줍니다 (끝난 세션으로 CLM을 부르는 건 정상 경로가 아님) |
| 404 | 없는 세션. AI서버는 401 |
| `usedSec` | 이어하기(F2-07) 세션이면 이미 쓴 시간. `startedAt`과 함께 있으면 경과 계산이 정확해집니다 |
| `recentObservations` | **선택.** F8-02(P1) 근거 기반 제안에 필요. 최근 3개면 충분. 스코프 컷 5번이 잘리면 필드도 빼셔도 됩니다 |
| `transcript`류 | **넣지 말아 주세요.** 필요 없고 노출면만 늘어납니다 |
| 호출 빈도 | **세션당 1회.** AI서버가 `hardCutSec + 30분` TTL로 캐시합니다. 실시간 경로에 매 턴 홉을 더하지 않습니다 |
| 조회 실패 시 AI서버 동작 | `.env` 고정 임계값으로 대화 계속 + 인증 통과 + 경고 로그. **백엔드가 내려가 있어도 대화는 됩니다** (F5-04와 같은 원칙) |

## 결정을 요청하는 것

1. 엔드포인트 신설에 동의하는지. 다른 전달 수단(세션 시작 시 백엔드 → AI서버 push 등)이 더 편하면 그쪽으로 맞추겠습니다.
2. 경로·필드명 확정.
3. `sessionId` 엔트로피를 128비트 이상(예: UUIDv4 또는 22자 base64url)으로 올려주실 수 있는지. 이게 안 되면 CLM 인증을 별도 수단으로 다시 설계해야 합니다.
4. `recentObservations` 포함 여부(P1 연동).
5. `live-turn-signal.md` 6번(데모 세션 적재 재시도 강화)이 AI서버 몫이면 알려주세요 — 재시도 횟수는 환경변수라 바로 올릴 수 있고, 데모 계정만 특별 처리하지 않고 전체를 올리는 쪽을 권합니다.

## 채택 시 고칠 위치

계약서는 백엔드가 고치고 버전을 올린 뒤 AI서버가 코드를 붙이겠습니다.

| 문서 | 위치 | 변경 |
| --- | --- | --- |
| api-contract.md | §3 **신규 3-4** | 엔드포인트 정의 (방향: AI서버 → 백엔드) |
| api-contract.md | §2-4·§2-5-1 | `sessionId` 예시를 새 형식으로 |
| api-contract.md | §4 | CLM 인증 방식 — "`custom_session_id` 검증, `language_model_api_key` 미사용" 명시 |
| api-contract.md | §6 변경 이력 | 다음 버전 |
| spec.md | F2-01 처리 | sessionId 생성 규칙 |
| spec.md | F2-03 처리 ① | "AI서버가 세션 컨텍스트의 `startedAt`·`softWrapSec`로 경과를 판단" 명시 |
| ai-pipeline.md | §7 | 확정값 반영 (AI가 수정) |

## 함께 알려드리는 것 (요청 아님)

- **Hume 콘솔 Config**(`request/backend/hume-config-id.md` 5번)는 AI 담당이 생성·소유하겠습니다. 발급된 `config_id`를 백엔드 환경변수로 드립니다. 콘솔 프롬프트는 비워둡니다 — 시스템 프롬프트는 AI서버가 씁니다.
- AI서버 배포 URL이 정해지면 Config의 CLM URL도 그에 맞춥니다. 로컬 개발은 ngrok이라 Config를 로컬용·배포용 둘로 나눌 가능성이 있습니다(앱 요청 문서가 지적한 대로). 그 경우 `config_id`도 환경별로 갈립니다.
