# Phase 3 — 턴 로그 수신 · 저장

> 목표: **대화가 끝나면 그 턴들이 DB에 남아 있는 상태**를 만든다. 여기가 서면 도그푸딩 데이터가 쌓이기 시작한다.
>
> 의존: Phase 2의 `voice_session` · Phase 1의 `turn_log`·`turn_tag`·`user_baseline` 테이블
>
> 근거: `spec.md` F5-01~04, F6-03, F3-04·F3-05 · `api-contract.md` §3-1·§3-2

> **이 Phase가 늦으면 그 기간의 로그는 영영 없다.** Phase 4~7은 나중에 만들어도 과거 턴을 다시 읽어 소급 처리되지만, 적재는 그 순간에만 가능하다 — `roadmap.md`.

## 3-1. 턴 로그 수신 — `POST /internal/turns` (F5-01)

- [ ] 헤더 `X-Internal-Secret` 검증 → 401 `INTERNAL_AUTH_FAILED` (계약 §3-1)
- [ ] 페이로드 수신 — 계약 §3-2

```json
{ "sessionId", "turnIndex", "role", "occurredAt", "transcript",
  "textValence", "voiceValence", "gap", "gapTriggered",
  "thresholdMode", "tags", "topProsody", "crisis" }
```

- [ ] `turn_log` 저장. **`transcript`는 암호화 컬럼(`transcript_enc`)으로**(3-2)
- [ ] `tags`를 `turn_tag`에 저장 — **백엔드는 태그를 재검증하지 않는다**(3-3)
- [ ] `crisis.detected == true`면 `crisis_event` 적재 — **발화 내용 없이**, `detected_by`는 `rule`/`llm`
- [ ] **응답 202** (본문 없음). 처리를 기다리게 하지 않는다

| 필드 | 규칙 |
| --- | --- |
| `role` | `assistant` 턴은 valence·gap이 **전부 null, tags는 빈 배열**로 온다. 그대로 저장 |
| `thresholdMode` | 세션 단위 값이라 `voice_session`에 이미 있다. **`turn_log`에 중복 저장하지 않는다** |
| `crisis` | `turn_log`에 저장하지 않는다 — `crisis_event`로만. **`turn_id`를 넣지 않는다**(백엔드 절대 원칙 2번) |
| `topProsody` | 상위 5개. `jsonb`로 그대로 |

- [ ] **중복 적재 처리** — `unique (session_id, turn_index)` 위반은 **오류가 아니라 "이미 적재됨"**으로 보고 202를 돌려준다

> **중복이 실제로 온다.** v1.3에서 `/internal/turns` 재시도를 1회 → **3회**로 올렸다(계약 §3-2). 백엔드가 저장에 성공하고 응답만 유실되면 AI서버는 실패로 보고 재시도한다. **제약 위반을 500으로 돌려주면 AI가 또 재시도하고, 로그에 오류가 쌓인다.**

> **이 호출은 fire-and-forget이다.** 무거운 처리를 여기 넣지 않는다 — 응답이 느려지면 AI서버의 대화 응답 경로에 영향이 갈 수 있다. baseline 재계산 같은 것은 세션 종료 시점에 한다(3-4).

## 3-2. 발화 텍스트 암호화 (F5-02)

- [ ] **AES-GCM** + JPA `AttributeConverter`
  - [ ] 엔티티 필드는 `String transcript` 그대로. 변환기가 저장 시 암호화, 조회 시 복호화
  - [ ] 키는 **환경변수**(`TRANSCRIPT_ENC_KEY` 등). `INTERNAL_SHARED_SECRET`·Hume 키와 같은 자리
  - [ ] `javax.crypto` 사용 — **의존성 추가 없음**
- [ ] **키를 저장소 밖에 따로 보관** — 아래 주의

> **왜 변환기인가** — 엔티티가 평문 `String`으로 남으므로 F7-07(관찰 근거 열람)·F9-05(대화 상세)가 **코드 수정 없이** 동작한다. 암호화를 서비스 코드에 흩으면 복호화를 빠뜨린 조회가 생기고, 그건 화면에 암호문이 뜨고 나서야 발견된다.

> **왜 pgcrypto가 아닌가** — DB에서 암호화하면 키가 SQL 쿼리에 실려 간다. Supabase가 뚫리는 상황을 가정한 방어인데 키가 같은 통로로 지나가면 반쯤 무의미하다.

> **⚠️ 키를 잃으면 도그푸딩 발화 전체가 복호화 불가가 된다.** F7-07(관찰 근거 열람)이 P0인데 통째로 죽고, §1.4의 "evidence 불일치 0건"을 증명할 수단이 사라진다. **DB 백업과 같은 급으로 다룬다.**

## 3-3. 태그 저장 (F6-03)

- [ ] `turn_tag`에 그대로 저장 (PK `(turn_id, tag)`)
- [ ] 태그 0개인 턴도 **`turn_log`는 저장**한다 — F7 집계에서만 빠질 뿐 valence·갭 통계에는 포함(spec F6-03)

> **백엔드가 태그를 추가·수정·재검증하지 않는다**(계약 §3-2). 원문 대조(F6-02)는 AI서버가 이미 끝냈다. 여기서 한 번 더 거르면 **같은 규칙이 두 곳에 생기고, 어긋나는 순간 §1.4 "원문 외 태그 0건" 지표의 근거가 어디인지 알 수 없어진다.**

## 3-4. baseline 갱신 (F3-05)

- [ ] **세션 종료 시** `user_baseline` 갱신 — 턴 적재 때마다가 아니다
- [ ] `session_count` +1, `avg_gap`·`stddev_gap` 재계산
- [ ] **갭이 NULL인 턴은 집계에서 제외**
- [ ] **전체 재계산으로 한다** (증분 아님) — `data-model.md` 참조. 세션 삭제(F10-01) 후 재계산과 **같은 코드**를 쓴다

> `session_count`가 **5**에 도달하는 순간 다음 세션의 `thresholdMode`가 `personal`로 바뀐다(F3-04). TC-07이 이 전환 로그를 확인한다.

## 3-5. 전송 실패 시 동작 (F5-04)

- [ ] 수신 엔드포인트가 **느리게 응답하지 않는지** 확인 — 무거운 작업 금지
- [ ] 저장 실패는 `ops_error_log`에 적재. **발화 내용·`sessionId`를 로그에 남기지 않는다**

> 재시도 정책(3회)은 **발신 측(AI서버) 몫**이다. 백엔드가 할 일은 "빨리 202를 주고, 중복은 조용히 넘기는 것"뿐이다.

## 완료 기준

- 대화 한 번이 끝나면 `turn_log`에 그 턴들이 남아 있다
- **DB를 직접 조회해도 평문 발화가 보이지 않는다** (F5-02 수용 기준)
- 같은 턴을 두 번 보내도 행이 하나만 생기고 202가 온다
- **TC-06** — 분석 호출 실패 턴(valence null, tags 빈 배열)이 정상 수신·저장된다
- **TC-11** — 서버·스토리지 어디에도 **오디오 파일 0건**
- **TC-15** — 원문에 없는 태그가 저장돼 있지 않다
- `ops_error_log`·애플리케이션 로그에 `transcript`·`sessionId`가 찍히지 않는다
- `api-spec.md`에서 `/internal/turns`를 `구현 완료`로 갱신했다

## 이 Phase에서 하지 않는 것

- **패턴 집계·관찰 생성** (Phase 4) — 여기서는 저장만 한다
- **턴 조회 API** (`/api/sessions/{id}`, `/api/session/{id}/live`) — Phase 5
- **태그 정규화·검증** — AI서버가 이미 했다
- **`crisis_event` 조회** — Phase 5의 `/live`에서
