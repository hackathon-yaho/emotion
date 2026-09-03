# API 계약서 — 감정 케어 보이스 저널

| 항목 | 내용 |
| --- | --- |
| 문서 버전 | v1.2 |
| 작성일 | 2026. 09. 03. |
| 상위 문서 | [prd.md](../00-context/prd.md) · [spec.md](../00-context/spec.md) · AI 내부 설계 [ai-pipeline.md](ai-pipeline.md) |
| 범위 | ① 앱 ↔ 백엔드 ② AI서버 ↔ 백엔드(내부) ③ Hume ↔ AI서버(외부·변경 불가) |

> **이 문서는 인터페이스의 단일 출처다.** PRD §8의 엔드포인트 표와 다르면 **이 문서가 우선**한다.
> 필드를 추가·삭제·개명하려면 **먼저 이 문서를 고치고 담당자에게 알린다.** 코드를 먼저 바꾸지 않는다.
> 3인이 병렬로 작업하므로, 이 문서에 적힌 것만 있으면 상대 파트가 완성되지 않아도 각자 진행할 수 있어야 한다.

---

# 1. 공통 규약

## 1-1. 기본

| 항목 | 값 |
| --- | --- |
| Base URL | 백엔드 배포 도메인 (환경변수로 주입, 앱에 하드코딩 금지) |
| 프로토콜 | HTTPS |
| Content-Type | `application/json; charset=utf-8` |
| 인증 | `Authorization: Bearer <JWT>` — `/api/auth/kakao`, `/api/health` 제외 전 엔드포인트 필수 |
| JWT 만료 | **7일.** 매일 쓰는 앱이라 더 짧으면 재로그인이 잦아 이탈 요인이 된다 |
| 시각 | **저장·전송은 UTC ISO 8601** (`2026-09-18T12:34:56Z`) |
| 일자 집계 | **KST(Asia/Seoul) 기준** — 사용자가 체감하는 "하루"가 기준이어야 트렌드가 맞다 |
| 소수 | valence·gap·ratio는 **소수 2자리 반올림**해서 응답한다 |

## 1-2. 오류 응답

모든 오류는 같은 모양이다.

```json
{
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "세션을 찾을 수 없습니다.",
    "traceId": "b17c9f2a"
  }
}
```

| HTTP | code | 발생 |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | 필수 파라미터 누락·형식 오류 |
| 401 | `UNAUTHORIZED` | JWT 없음 |
| 401 | `TOKEN_EXPIRED` | JWT 만료 — 앱은 카카오 재로그인으로 갱신 |
| 401 | `KAKAO_VERIFY_FAILED` | 카카오 액세스 토큰 검증 실패 |
| 401 | `INTERNAL_AUTH_FAILED` | 내부 API 공유 시크릿 불일치 |
| 403 | `FORBIDDEN` | 다른 사용자의 리소스 접근 |
| 404 | `NOT_FOUND` | 리소스 없음 (`SESSION_NOT_FOUND`, `OBSERVATION_NOT_FOUND`) |
| 409 | `SESSION_NOT_RESUMABLE` | 이어하기 창(30분) 경과 또는 잔여 시간 없음 |
| 503 | `HUME_TOKEN_ISSUE_FAILED` | Hume 액세스 토큰 발급 실패 |
| 500 | `INTERNAL_ERROR` | 그 외 |

> **`message`는 사용자에게 그대로 보여도 되는 한국어 문장으로 쓴다.** 앱이 code별 문구를 다시 만들지 않아도 되게 한다. 단 앱이 분기해야 하는 경우엔 **`code`로 분기하고 `message`로 분기하지 않는다.**

## 1-3. null 규칙

계약에서 `null`은 **"측정하지 못했다"**는 뜻이며, 0이나 기본값으로 대체하지 않는다.

| 필드 | null이 되는 경우 | 소비 측 처리 |
| --- | --- | --- |
| `textValence` | 텍스트 valence 분석 호출 실패·타임아웃 (spec F3-06) | 갭 미표시 |
| `voiceValence` | 프로소디 점수 누락, 또는 긍정·부정 합계 질량이 기준(초기 0.05) 미만 — 중립만 찍힌 발화 ([ai-pipeline.md](ai-pipeline.md) §3) | 갭 미표시 |
| `gap` | 위 둘 중 **하나라도** null | 그래프에서 점을 찍지 않는다 |
| `summary` | 요약 생성 실패 | 요약 영역 숨김 |
| `observations[]` | 조건 미달로 관찰 미생성 | **빈 배열.** "아직 없어요" 안내만 표시하고 억지 문구를 만들지 않는다 |

**그래프에서 값이 없는 날은 배열에서 아예 생략한다.** 0으로 채우거나 앞뒤를 이어 보간하지 않는다 — 없는 감정을 그리는 것이기 때문이다.

## 1-4. 목록 페이징

| 파라미터 | 기본 | 최대 |
| --- | --- | --- |
| `limit` | 20 | 100 |
| `offset` | 0 | — |

응답에 `total`을 포함한다. 정렬은 **항상 최신순**(`createdAt`/`startedAt` 내림차순)이며 클라이언트가 바꾸지 않는다.

---

# 2. 앱 ↔ 백엔드

## 2-1. `POST /api/auth/kakao` — 로그인

인증 불필요.

**요청**

```json
{ "kakaoAccessToken": "AAAA..." }
```

**응답 200**

```json
{
  "jwt": "eyJhbGciOi...",
  "expiresAt": "2026-09-18T12:34:56Z",
  "profileId": "prof_7f3a2b",
  "isNewUser": true
}
```

| 오류 | 조건 |
| --- | --- |
| 400 `VALIDATION_ERROR` | `kakaoAccessToken` 누락 |
| 401 `KAKAO_VERIFY_FAILED` | 카카오 검증 실패 |
| 503 `INTERNAL_ERROR` | 카카오 API 장애 |

> `isNewUser`는 앱이 온보딩 고지(spec F1-05)를 띄울지 판단하는 데만 쓴다.
> 재로그인 시 **동일한 `profileId`**가 반환되어야 한다 (spec TC-01).

## 2-2. `GET /api/me` — 내 정보

**응답 200**

```json
{
  "profileId": "prof_7f3a2b",
  "joinedAt": "2026-09-05T10:00:00Z",
  "sessionCount": 7,
  "thresholdMode": "personal",
  "demoMode": false,
  "openSession": {
    "sessionId": "sess_9c1d4e",
    "startedAt": "2026-09-18T12:30:00Z",
    "usedSec": 138,
    "remainingSec": 282,
    "resumableUntil": "2026-09-18T13:03:22Z"
  }
}
```

| 필드 | 설명 |
| --- | --- |
| `openSession` | **비정상 중단으로 열려 있는 세션.** 없으면 `null` |
| `remainingSec` | `hardCutSec − usedSec`. 이어하기해도 **원가 상한이 유지되도록** 남은 시간만 준다 |
| `resumableUntil` | 이 시각을 넘기면 스케줄러가 자동 종료한다 (중단 후 30분) |

> 홈(S01)과 설정(S06)이 공용으로 쓴다. `thresholdMode`는 표시용이며, 실제 적용 값은 세션 시작 시점에 다시 내려온다(2-4).
> 앱은 `openSession != null`이면 홈에서 **"이어서 이야기할까요?"**를 제안한다 (spec F2-07).

## 2-3. `DELETE /api/account` — 탈퇴

**응답 204** (본문 없음)

| 오류 | 조건 |
| --- | --- |
| 500 `INTERNAL_ERROR` | 삭제 트랜잭션 실패 — **부분 삭제 상태를 남기지 않고 롤백** |

> 삭제 대상 10개 테이블은 spec F10-03 참조. 유예 기간을 두지 않는다.

## 2-4. `POST /api/session/start` — 대화 세션 시작

**요청**: 본문 없음

**응답 201**

```json
{
  "sessionId": "sess_9c1d4e",
  "humeAccessToken": "hume_at_...",
  "humeTokenExpiresAt": "2026-09-18T12:44:56Z",
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "softWrapSec": 300,
  "hardCutSec": 420,
  "demoMode": false
}
```

| 필드 | 설명 |
| --- | --- |
| `humeAccessToken` | **단기 토큰.** Hume API 키는 절대 내려보내지 않는다 (spec TC-03) |
| `thresholdMode` | `"fixed"` (세션 5회 미만) / `"personal"` (5회 이상) |
| `gapThreshold` | 이번 세션에 적용되는 실제 임계값. 앱은 표시하지 않고 **데모 모드에서만** 참고. **예시의 `0.85`는 확정값이 아니다** — 초기 수치는 20쌍 세트 측정 후 결정(PRD §14-5) |
| `softWrapSec` · `hardCutSec` | 300 / 420 고정. **서버가 내려주는 값을 쓰고 앱에 상수로 박지 않는다** — 정책 변경 시 배포 없이 바꾸기 위함 |

| 오류 | 조건 |
| --- | --- |
| 503 `HUME_TOKEN_ISSUE_FAILED` | Hume 토큰 발급 실패 → 앱은 대화 시작을 **차단**하고 안내 |

## 2-5. `POST /api/session/{sessionId}/end` — 세션 종료

**요청**

```json
{ "endReason": "user_end" }
```

`endReason`: `"user_end"` | `"soft_wrap"` | `"hard_cut"` | `"timeout"`(스케줄러 전용) | `"resumed"`(이어하기로 승계됨)

> 앱은 `timeout`·`resumed`를 보내지 않는다. 서버 내부에서만 기록한다.

**응답 200**

```json
{
  "sessionId": "sess_9c1d4e",
  "durationSec": 214,
  "turnCount": 12,
  "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
  "gapAvg": 0.94
}
```

| 오류 | 조건 |
| --- | --- |
| 404 `SESSION_NOT_FOUND` | — |
| 403 `FORBIDDEN` | 타 사용자 세션 |

> 종료 처리는 **패턴 분석 배치 큐 적재**(spec F7-01)를 포함한다. 배치는 비동기이므로 이 응답에 관찰이 포함되지 않는다.
> **`summary`는 null일 수 있다**(생성 실패). 대화 기록 자체는 남는다.

## 2-5-1. `POST /api/session/{sessionId}/resume` — 중단 세션 이어하기 (P1)

`GET /api/me`의 `openSession`이 있을 때만 호출한다.

**응답 200**

```json
{
  "sessionId": "sess_9c1d4e",
  "humeAccessToken": "hume_at_...",
  "humeTokenExpiresAt": "2026-09-18T13:05:00Z",
  "resumedChatGroupId": "cg_2b7f11",
  "remainingSec": 282,
  "thresholdMode": "fixed",
  "gapThreshold": 0.85,
  "demoMode": false
}
```

| 필드 | 설명 |
| --- | --- |
| `resumedChatGroupId` | 앱이 EVI 핸드셰이크의 `resumed_chat_group_id` 쿼리 파라미터로 넘긴다. **이전 대화 맥락이 복원된다** — [Resuming Chats](https://dev.hume.ai/docs/speech-to-speech-evi/features/resume-chats) |
| `remainingSec` | `hardCutSec − usedSec`. **새 7분을 주지 않는다** — 이어하기로 원가 상한이 뚫리면 안 된다 (PRD NFR-06) |

| 오류 | 조건 |
| --- | --- |
| 404 `SESSION_NOT_FOUND` | 이미 종료·정리된 세션 |
| 409 `SESSION_NOT_RESUMABLE` | `resumableUntil` 경과 또는 `remainingSec <= 0` |

> **이어하기 창은 중단 후 30분이다.** 하드컷이 7분이라 정상 세션은 걸리지 않고, 감정 대화에서 몇 시간 뒤에 잇는 것은 이미 다른 대화이기 때문이다.
> 사용자가 "아니오"를 고르면 앱은 이 대신 `POST /api/session/{id}/end`(`endReason: "user_end"`)를 호출해 그 세션을 닫는다.

## 2-6. `GET /api/observations` — 관찰 목록

**쿼리**: `limit`, `offset`

**응답 200**

```json
{
  "total": 3,
  "observations": [
    {
      "observationId": "obs_014",
      "createdAt": "2026-09-18T09:00:00Z",
      "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.",
      "evidence": {
        "tag": "회의",
        "occurrences": 7,
        "tagAvgGap": 1.31,
        "userAvgGap": 0.72,
        "ratio": 1.82
      },
      "feedback": null
    }
  ]
}
```

`feedback`: `"agree"` | `"disagree"` | `null`(미응답)

> **`evidence`는 목록에서도 반드시 함께 내려간다.** 관찰 문장만 있고 근거가 없는 상태를 계약 수준에서 만들지 않기 위함이다 (PRD FR-053).
> 관찰이 없으면 `observations: []`, `total: 0`. 앱은 안내 문구만 띄우고 **가짜 관찰을 만들지 않는다.**

## 2-7. `GET /api/observations/{observationId}/evidence` — 관찰 근거

**응답 200**

```json
{
  "observationId": "obs_014",
  "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.",
  "evidence": {
    "tag": "회의",
    "occurrences": 7,
    "tagAvgGap": 1.31,
    "userAvgGap": 0.72,
    "ratio": 1.82
  },
  "turns": [
    {
      "turnId": "turn_0031",
      "sessionId": "sess_9c1d4e",
      "occurredAt": "2026-09-12T13:20:11Z",
      "transcript": "오늘 회의가 세 개나 있었는데 다 괜찮았어요",
      "textValence": 0.62,
      "voiceValence": -0.58,
      "gap": 1.20
    }
  ]
}
```

| 오류 | 조건 |
| --- | --- |
| 404 `OBSERVATION_NOT_FOUND` | 근거 대화가 삭제되어 관찰이 무효화된 경우 포함 (spec F10-02) |

> **`turns` 길이는 `evidence.occurrences`와 반드시 같다.** 다르면 계약 위반이며 PRD §1.4의 "evidence 불일치 0건" 지표 실패로 집계한다.

## 2-7-1. `POST /api/observations/{observationId}/feedback` — 관찰 피드백 (P1)

**요청**

```json
{ "feedback": "disagree" }
```

`feedback`: `"agree"` | `"disagree"` — 관찰당 **1회**. 재호출 시 덮어쓴다.

**응답 200**

```json
{ "observationId": "obs_014", "feedback": "disagree" }
```

> **`disagree`는 관찰을 삭제하지 않는다.** 표시만 남긴다 — 사용자가 부정했다고 우리가 계산한 숫자가 틀린 것은 아니고, evidence는 그대로 유효하다. 삭제하면 PRD §1.4의 "evidence 불일치 0건" 판정 대상이 사라져 지표가 왜곡된다.
> 이유 입력·취소는 제공하지 않는다. 붙는 순간 P1 범위를 벗어난다.

## 2-8. `GET /api/trend` — 감정 추세 (두 선 그래프)

**쿼리**: `range` = `7d` | `30d` | `90d` (기본 `30d`)

**응답 200**

```json
{
  "range": "30d",
  "timezone": "Asia/Seoul",
  "points": [
    { "date": "2026-09-12", "textValence": 0.61, "voiceValence": -0.42, "gap": 1.03, "sessionCount": 1 },
    { "date": "2026-09-14", "textValence": 0.20, "voiceValence": 0.11, "gap": 0.09, "sessionCount": 2 }
  ],
  "highlights": [
    { "from": "2026-09-11", "to": "2026-09-13", "reason": "gap_exceeded" }
  ]
}
```

| 규칙 | 내용 |
| --- | --- |
| 없는 날 | `points`에서 **생략**한다. 0으로 채우거나 보간하지 않는다 |
| 값 범위 | `textValence`·`voiceValence`는 −1.00 ~ 1.00 |
| 하루에 2세션 이상 | 그날의 **평균**. `sessionCount`로 표시 |
| `highlights` | 갭이 임계를 넘은 **연속 구간**. 앱은 이 구간을 음영 처리하고, 탭하면 해당 날짜의 대화 상세로 이동 (spec F9-02) |

## 2-9. `GET /api/sessions` — 대화 기록 목록

**쿼리**: `limit`, `offset`

**응답 200**

```json
{
  "total": 12,
  "sessions": [
    {
      "sessionId": "sess_9c1d4e",
      "startedAt": "2026-09-18T12:30:00Z",
      "durationSec": 214,
      "turnCount": 12,
      "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
      "gapAvg": 0.94,
      "tags": ["회의", "야근"]
    }
  ]
}
```

`tags`는 그 세션에서 가장 많이 등장한 상위 3개까지.

## 2-10. `GET /api/sessions/{sessionId}` — 대화 상세

**응답 200**

```json
{
  "sessionId": "sess_9c1d4e",
  "startedAt": "2026-09-18T12:30:00Z",
  "endedAt": "2026-09-18T12:33:34Z",
  "durationSec": 214,
  "endReason": "user_end",
  "thresholdMode": "fixed",
  "summary": "회의가 많았던 하루에 대해 이야기했습니다.",
  "turns": [
    {
      "turnId": "turn_0031",
      "turnIndex": 3,
      "occurredAt": "2026-09-18T12:31:02Z",
      "role": "user",
      "transcript": "오늘 완전 괜찮았어요",
      "textValence": 0.70,
      "voiceValence": -0.62,
      "gap": 1.32,
      "gapTriggered": true,
      "tags": ["회의"]
    },
    {
      "turnId": "turn_0032",
      "turnIndex": 4,
      "occurredAt": "2026-09-18T12:31:06Z",
      "role": "assistant",
      "transcript": "괜찮다고 하시는데 목소리는 좀 다르네요. 무슨 일 있으셨어요?",
      "textValence": null,
      "voiceValence": null,
      "gap": null,
      "gapTriggered": false,
      "tags": []
    }
  ]
}
```

> **assistant 턴은 valence·gap이 전부 `null`이다.** 측정 대상은 사용자 발화뿐이다.
> 갭 수치는 **이 화면에서는 노출된다.** 대화 중 화면(S02)과 구분되는 지점이다 (PRD FR-031).

## 2-11. `DELETE /api/sessions/{sessionId}` — 대화 삭제

**응답 200**

```json
{
  "deletedSessionId": "sess_9c1d4e",
  "deletedTurnCount": 12,
  "removedObservationIds": ["obs_014"],
  "recalculatedObservationIds": ["obs_009"]
}
```

| 필드 | 의미 |
| --- | --- |
| `removedObservationIds` | 남은 근거가 3회 미만이 되어 **삭제된** 관찰 |
| `recalculatedObservationIds` | 근거는 남았으나 **숫자가 재계산된** 관찰 |

> 앱은 이 응답을 받으면 관찰 목록 캐시를 무효화한다. 근거를 잃은 관찰이 화면에 남아 있으면 그 순간 "근거 없는 문장"이 된다 (PRD FR-081).
> 이 호출은 `user_baseline` 재계산도 함께 수행한다 (spec F3-05).

## 2-12. `GET /api/health` — 헬스체크

인증 불필요.

**응답 200**

```json
{ "status": "ok", "db": "ok", "timestamp": "2026-09-18T12:34:56Z" }
```

DB 연결 확인을 포함한다. **Supabase 유휴 일시정지 방지용 주기 호출**에도 사용한다.

---

# 3. AI서버 → 백엔드 (내부)

## 3-1. 인증

| 항목 | 값 |
| --- | --- |
| 헤더 | `X-Internal-Secret: <공유 시크릿>` |
| 실패 | 401 `INTERNAL_AUTH_FAILED` |

시크릿은 양쪽 환경변수로만 주입한다. 리포지토리에 넣지 않는다.

## 3-2. `POST /internal/turns` — 턴 로그 적재

**요청**

```json
{
  "sessionId": "sess_9c1d4e",
  "turnIndex": 3,
  "role": "user",
  "occurredAt": "2026-09-18T12:31:02Z",
  "transcript": "오늘 완전 괜찮았어요",
  "textValence": 0.70,
  "voiceValence": -0.62,
  "gap": 1.32,
  "gapTriggered": true,
  "thresholdMode": "fixed",
  "tags": ["회의"],
  "topProsody": { "Tiredness": 0.71, "Sadness": 0.42, "Joy": 0.06 },
  "crisis": { "detected": false, "by": null }
}
```

| 필드 | 규칙 |
| --- | --- |
| `role` | `"user"` \| `"assistant"`. assistant 턴은 valence·gap·tags가 전부 null/빈 배열 |
| `tags` | **원문 대조 검증을 통과한 태그만** 보낸다 (spec F6-02). 백엔드는 재검증하지 않는다 |
| `topProsody` | 상위 5개까지. 디버깅·재현성 검증용 |
| `crisis.by` | `"rule"` \| `"llm"` \| `null` |
| **음성 원본** | **필드 자체가 없다.** 어떤 형태로도 전송하지 않는다 (PRD FR-041) |

**응답 202** (본문 없음)

| 오류 | AI서버 동작 |
| --- | --- |
| 4xx | 재시도하지 않는다. `ops_error_log` 적재 후 진행 |
| 5xx · 타임아웃 | **1회만 재시도** 후 포기 |

> **이 호출은 fire-and-forget이다.** 실패해도 대화 응답을 막지 않는다 (spec F5-04). 백엔드가 내려가 있어도 사용자는 대화를 계속할 수 있어야 한다.

## 3-3. `POST /internal/observations` — 관찰 문장 반환 (배치)

백엔드가 집계·판정을 마친 뒤 AI서버에 문장화를 요청하고, 그 결과를 저장하는 경로.

**백엔드 → AI서버 요청**

```json
{
  "tag": "회의",
  "occurrences": 7,
  "tagAvgGap": 1.31,
  "userAvgGap": 0.72,
  "ratio": 1.82
}
```

**AI서버 응답 200**

```json
{ "sentence": "회의 얘기를 하실 때만 목소리가 유독 무거워지시네요." }
```

| 규칙 | 내용 |
| --- | --- |
| 입력 | **숫자와 태그만.** 원본 대화를 보내지 않는다 |
| 출력 | 한 문장. **주어진 숫자를 바꾸거나 없는 사실을 추가하지 않는다** (PRD §9.3 조항 7) |
| 실패 | 관찰을 생성하지 않는다. **템플릿 문장으로 대체하지 않는다** — 표현이 어색한 것보다 근거 없는 문장이 나가는 쪽이 위험하다 |

---

# 4. Hume ↔ AI서버 (외부 계약 · 변경 불가)

우리가 정의하는 계약이 아니라 **Hume이 정한 규격**이다. 맞추는 쪽은 우리다.

| 항목 | 값 |
| --- | --- |
| 엔드포인트 | `POST /chat/completions?custom_session_id={sessionId}` |
| 인증 | `Authorization: Bearer <api_key>` |
| 요청 | `messages[]` — `role`, `content`, `time{begin,end}`, `models.prosody.scores{48종}` |
| 응답 | **SSE.** `Content-Type: text/event-stream`, OpenAI `ChatCompletionChunk` 청크 스트리밍 후 `data: [DONE]` |
| 세션 식별 | 응답 청크의 `system_fingerprint`에 세션 ID 반영 |

**요청 예시**

```json
{
  "messages": [
    {
      "role": "user",
      "content": "오늘 완전 괜찮았어요",
      "time": { "begin": 12400, "end": 14100 },
      "models": { "prosody": { "scores": { "Tiredness": 0.71, "Sadness": 0.42, "Joy": 0.06 } } }
    }
  ],
  "model": "our-clm"
}
```

**응답 예시**

```
data: {"choices":[{"delta":{"content":"괜찮다고 하시는데 "}}],"system_fingerprint":"sess_9c1d4e"}

data: {"choices":[{"delta":{"content":"목소리는 좀 다르네요. 무슨 일 있으셨어요?"}}]}

data: [DONE]
```

> **이 스트림에는 대화 텍스트만 실린다.** 텍스트 valence·태그·위기 판정은 응답 호출과 분리된 분석 호출에서 나오므로(spec F3-02, v1.2), 스트림에 메타 태그·JSON이 섞일 경로 자체가 없다. 섞여 나오면 즉시 결함이다 — 사용자에게 음성으로 읽힌다.
> **CLM 인증**: `language_model_api_key`는 앱이 `session_settings`로 보내야 해서 웹 번들에 노출된다. AI서버는 대신 `custom_session_id`를 백엔드 세션 조회로 검증한다 — `request/backend/session-context-lookup.md` (회신 대기, 확정 시 이 절에 반영).

출처: [Hume Custom Language Model 가이드](https://dev.hume.ai/docs/speech-to-speech-evi/guides/custom-language-model)

---

# 5. 화면 ↔ 엔드포인트 매핑

| 화면 | 호출 |
| --- | --- |
| S00 진입·로그인 | `POST /api/auth/kakao` |
| S01 홈 | `GET /api/me`(`openSession` 포함), `GET /api/observations?limit=3` |
| S02 대화 | `POST /api/session/start` **또는** `POST /api/session/{id}/resume` → (Hume 직접 연결) → `POST /api/session/{id}/end` |
| S02-1 종료 요약 | 2-5 응답 재사용 (추가 호출 없음) |
| S03 발견 | `GET /api/observations`, `POST /api/observations/{id}/feedback` |
| S03-1 관찰 근거 | `GET /api/observations/{id}/evidence` |
| S04 트렌드 | `GET /api/trend?range=30d` |
| S05 기록 | `GET /api/sessions` |
| S05-1 대화 상세 | `GET /api/sessions/{id}`, `DELETE /api/sessions/{id}` |
| S06 설정 | `GET /api/me`, `DELETE /api/account` |
| S07 위기 안내 | 없음 — 앱 로컬 표시. 적재는 AI서버가 `/internal/turns`의 `crisis`로 처리 |

---

# 6. 변경 절차

1. 이 문서를 먼저 고치고 **버전을 올린다**
2. 변경 이력에 **무엇을 왜 바꿨는지** 적는다
3. 영향받는 담당자에게 알린다 (앱 / 백엔드 / AI)
4. 그 다음에 코드를 바꾼다

**필드 삭제·개명은 특히 주의한다.** 3인이 병렬로 가는 동안 상대는 이 문서만 보고 만들고 있다.

## 변경 이력

| 버전 | 일자 | 내용 |
| --- | --- | --- |
| v1.0 | 2026-09-03 | 최초 작성. PRD §8·spec 기준으로 12개 공개 엔드포인트 + 2개 내부 엔드포인트 확정 |
| v1.1 | 2026-09-03 | 문서 교차 검증 반영 — ① `POST /api/session/{id}/resume` 신설(중단 세션 이어하기) ② `POST /api/observations/{id}/feedback` 신설(측정 절차가 없던 §1.4 "맞아요" 지표를 실제로 수집 가능하게) ③ `GET /api/me`에 `openSession` 추가 ④ `endReason`에 `timeout`·`resumed` 추가 ⑤ 409 `SESSION_NOT_RESUMABLE` 추가 ⑥ JWT 만료 7일 명시 ⑦ `gapThreshold` 예시값 표기 |
| v1.2 | 2026-09-03 | AI 파이프라인 개정 반영(`request/ai/clm-turn-pipeline-review.md` 회신) — ① §1-3 `textValence` null 사유를 "분석 호출 실패·타임아웃"으로 ② §4 마지막 경고를 "메타 태그 없음"으로, CLM 인증 방향 각주 ③ 상위 문서에 `ai-pipeline.md` 추가 ④ §1-3 `voiceValence` null 사유에 합계 질량 부족(중립만 찍힌 발화) 추가. **필드 변경 없음.** 계약 공백 2건은 별도 요청(`request/backend/session-context-lookup.md`, `session-summary-endpoint.md`)으로 다음 버전에서 |
