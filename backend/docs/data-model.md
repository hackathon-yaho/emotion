# 데이터 모델 — 백엔드

> **수정 기록 (2026-09-04 ②)** — 계약 v1.4 반영. **컬럼 2개 신설** — `voice_session.gap_threshold`(F9-02 음영 판정이 쓸 임계값 스냅샷. 안 두면 임계값 확정 시 과거 음영이 소급 변경된다)·`profile.demo_mode`(F11-01 플래그의 실체가 어디에도 없었다). **F3-04에 `avg_gap IS NOT NULL` 가드**를 반영하고 `session_count` 증가를 F3-05에서 분리했다. `observation_evidence` 절의 "숫자 4개" 표현을 정정 — 계약 §2-6의 `evidence` 객체는 **`tag`를 포함한 5키**다. 로그 상관용 **`sessionRef`** 규칙 추가.
>
> **수정 기록 (2026-09-04 ①)** — 문서 신설. `spec.md` §6-1은 "무엇을 저장하는가"(컬럼명·개인정보 여부)까지만 정의하고 타입·제약·인덱스·FK가 없어, 구현에 필요한 DDL을 여기서 확정한다. 작성 중 발견한 공백 3건은 아래 "spec과 달라진 점"에 적었다.

`spec.md` §6-1이 **무엇을** 저장할지의 단일 출처이고, 이 문서는 **어떻게** 저장할지를 정한다. 컬럼이 추가·삭제되면 **§6-1을 먼저 고치고** 여기를 따라 고친다.

- 산출물은 `src/main/resources/db/migration.sql` 하나다. `ddl-auto: none`이므로 **JPA가 스키마를 만들지 않는다.**
- 같은 SQL을 **로컬 compose Postgres와 배포 Supabase 양쪽에** 적용한다.
- 앱·AI는 이 문서를 볼 필요가 없다. 그쪽이 보는 필드 정의는 `api-contract.md`다.

## spec §6-1과 달라진 점 (작성 중 발견)

| 지점 | 내용 | 처리 |
| --- | --- | --- |
| `turn_log.role` | 계약 §2-10 응답과 §3-2 요청이 `role`(`user`/`assistant`)을 주고받는데 **§6-1 컬럼 목록에 없다** | **컬럼 추가.** 없으면 §2-10 응답을 만들 수 없다. spec §6-1 개정 필요 |
| `turn_log.occurred_at` | 계약이 `occurredAt`(발화 시각, AI가 보냄)을 요구하는데 §6-1엔 `created_at`(적재 시각)만 있다 | **둘 다 둔다.** 적재가 지연·재시도되면 두 값이 갈린다 |
| `voice_session.pattern_processed_at` | 배치 트리거를 스케줄러 방식으로 정하면서(2026-09-04) 필요해진 컬럼 | **컬럼 추가.** spec §6-1·F7-01 개정 완료 |
| `voice_session.gap_threshold` | 계약 §2-8 `highlights`가 "갭이 임계를 넘은 구간"인데, 세션에 **실제로 적용된 임계값 수치**가 저장되지 않았다(`threshold_mode`만 있었다) | **컬럼 추가.** 임계값은 PRD §14-5로 반드시 한 번 바뀌고, 바뀌면 과거 음영이 소급 재판정된다. spec §6-1·F9-02 개정 완료 (계약 v1.4) |
| `profile.demo_mode` | F11-01 데모 플래그의 저장 위치가 어느 문서에도 없었다. `GET /api/me`·`session/start`·`/live`·`/internal/sessions` 네 곳이 이 값을 읽는다 | **컬럼 추가.** 환경변수 목록은 값을 바꾸는 데 재배포가 필요하고, 스키마는 어차피 지금 한 번에 만든다. spec §6-1·F11-01 개정 완료 |

## 공통 규약

| 항목 | 값 | 이유 |
| --- | --- | --- |
| PK 타입 | **`uuid`** (`gen_random_uuid()`) | `sessionId`가 CLM 인증 수단이라 추측 불가해야 한다(계약 §1-1). 나머지도 같은 타입으로 맞춰 조인·코드를 단순하게 |
| 시각 | **`timestamptz`**, 저장·전송은 UTC | 계약 §1-1. 일자 집계만 KST로 변환 |
| valence·gap | **`numeric(3,2)`** | −1.00~1.00(gap은 0.00~2.00). 계약이 소수 2자리 반올림을 규정 |
| 소수 NULL | valence·gap은 **NULL 허용** | 계약 §1-3 — NULL은 "측정하지 못했다"는 뜻이며 0으로 대체하지 않는다 |
| FK | **전부 명시, `ON DELETE NO ACTION`** | 삭제 건수를 응답에 담아야 해서(계약 §2-11) 앱이 순서대로 지운다. 아래 "삭제 순서" |
| 확장 | `pgcrypto` **사용 안 함** | 발화 암호화는 앱 레벨 AES-GCM(F5-02). 키가 SQL로 흐르지 않게 |

> **`gen_random_uuid()`는 PostgreSQL 13+ 내장**이라 확장 설치가 필요 없다. Postgres 16(로컬)·Supabase 모두 해당.

## 테이블

### 계정 · 프로필 (F1 · 식별자 분리)

```sql
create table account (
    id          uuid primary key default gen_random_uuid(),
    kakao_id    text        not null unique,
    created_at  timestamptz not null default now()
);

create table profile (
    id          uuid primary key default gen_random_uuid(),
    demo_mode   boolean     not null default false,
    created_at  timestamptz not null default now()
);

create table account_profile (
    account_id  uuid primary key references account(id),
    profile_id  uuid not null unique references profile(id)
);
```

| 컬럼 | 규칙 |
| --- | --- |
| `account.kakao_id` | **카카오 회원번호** — `GET /v2/user/me`의 `id`를 문자열로 저장한다(F1-01 ③). 카카오 회원번호는 64비트 정수라 `bigint`도 되지만, **식별자를 산술 대상으로 만들지 않으려고** `text`로 둔다 |

> **`kakao_sub`이 아니라 `kakao_id`인 이유 (2026-09-04)** — `sub`은 OIDC ID 토큰의 클레임 이름이다. 우리 흐름은 **액세스 토큰을 받아 `/v2/user/me`를 부르는 방식**이라 실제로 저장되는 값은 `id`(회원번호)다. 이름과 값이 다르면 구현할 때 "OIDC를 써야 하나" 하고 한 번 멈춘다. 코드가 없는 지금이 고치는 비용이 0인 유일한 시점이다.

> **감정 데이터는 `profile_id`만 참조한다.** `account`(카카오 식별자)와의 연결은 `account_profile` 한 곳에만 있다 — PRD §5.1 식별자 분리. 이 테이블을 조인하지 않으면 어떤 감정 데이터도 실명 계정에 닿지 않는다.
> **`demo_mode`가 `account`가 아니라 `profile`에 있는 이유** — 조회 경로가 전부 `profileId` 기반이다. `account`에 두면 데모 여부를 볼 때마다 `account_profile` 조인이 붙는데, 그 조인은 식별자 분리가 막으려는 바로 그 경로다. **심사 당일에는 `UPDATE profile SET demo_mode = true WHERE id = ?` 한 줄로 켠다 — 재배포가 필요 없다.**

### 대화 세션 (F2)

```sql
create table voice_session (
    id                   uuid primary key default gen_random_uuid(),
    profile_id           uuid        not null references profile(id),
    started_at           timestamptz not null default now(),
    ended_at             timestamptz,
    duration_sec         integer,
    threshold_mode       text        not null check (threshold_mode in ('fixed','personal')),
    gap_threshold        numeric(3,2) not null,
    end_reason           text        check (end_reason in ('user_end','soft_wrap','hard_cut','timeout','resumed')),
    summary              text,
    hume_chat_group_id   text,
    pattern_processed_at timestamptz
);

create index idx_session_profile_started on voice_session (profile_id, started_at desc);
create index idx_session_open            on voice_session (profile_id) where ended_at is null;
create index idx_session_batch_pending   on voice_session (ended_at) where ended_at is not null and pattern_processed_at is null;
```

| 컬럼 | 규칙 |
| --- | --- |
| `id` | **UUIDv4.** CLM 인증에 `custom_session_id`로 쓰이므로 **로그에 남기지 않는다**(백엔드 절대 원칙 6번) |
| `threshold_mode` | `session_count >= 5` **AND** `avg_gap IS NOT NULL`이면 `personal`, 아니면 `fixed`(F3-04, 2026-09-04 가드 추가). **가드가 없으면 5세션 내내 분석이 실패한 사용자가 평균 없이 `personal`로 넘어간다** |
| `gap_threshold` | **세션 시작 시 실제로 적용한 임계값 수치를 그대로 박는다.** F9-02 음영(계약 §2-8 `highlights`)이 이 값으로 판정한다. `NOT NULL` — 세션이 시작됐다면 임계값은 반드시 정해져 있다 |
| `ended_at` `duration_sec` | 종료 전에는 NULL. `duration_sec`는 종료 시 계산해 넣는다 |
| `end_reason` | 앱은 `timeout`·`resumed`를 보내지 않는다(계약 §2-5). 서버 내부에서만 기록 |
| `summary` | **NULL 가능** — 생성 실패·`endReason: timeout`(§2-5) |
| `pattern_processed_at` | **NULL이면 배치 미처리.** 스케줄러가 이 조건으로 훑는다(F7-01) |
| `resumableUntil` | **컬럼을 두지 않는다.** `coalesce(max(turn_log.occurred_at), started_at) + 30분`으로 계산한다 (2026-09-04 정정) — 아래 주의 |

> **`resumableUntil`을 `ended_at`으로 계산할 수 없다** (2026-09-04, Phase 2 구현 중 발견). `openSession`은 **아직 열려 있는**(`ended_at IS NULL`) 세션이므로 `ended_at + 30분`은 계산 자체가 성립하지 않는다. 그렇다고 `started_at + 30분`으로 두면 **TC-22가 깨진다** — 2분 말하고 앱이 죽은 뒤 5분 지나 이어하기를 누르면 벽시계로는 7분이 흘러 잔여 시간이 0이 되고 409로 막힌다. 앱이 죽으면 종료 신호가 오지 않으므로 **서버가 아는 마지막 활동은 마지막 턴의 `occurred_at` 하나뿐**이고, 이어하기 창·`usedSec`·F2-06 정리가 전부 이 값에서 갈린다. 턴이 없으면 `started_at`이다(시작만 하고 말하지 않은 세션). 계약 §2-2의 정의("중단 후 30분")와도 이쪽이 맞는다.

> **`gap_threshold`를 스냅샷하는 이유** — 초기 수치는 20쌍 세트 측정 후 확정된다(PRD §14-5). 현재 설정값으로 소급 판정하면 **수치를 확정하는 순간 과거 날짜의 음영이 통째로 달라져**, 그날 앱이 실제로 되물었던 근거(FR-022)와 화면이 어긋난다. 컬럼 하나로 그 경로를 막는다.
> `idx_session_batch_pending`은 **부분 인덱스**다. 처리 끝난 세션은 인덱스에서 빠지므로, 도그푸딩이 길어져도 배치 스캔 비용이 늘지 않는다.

### 턴 로그 (F3 · F5 · F6)

```sql
create table turn_log (
    id             uuid primary key default gen_random_uuid(),
    session_id     uuid        not null references voice_session(id),
    turn_index     integer     not null,
    role           text        not null check (role in ('user','assistant')),
    occurred_at    timestamptz not null,
    transcript_enc text        not null,
    text_valence   numeric(3,2),
    voice_valence  numeric(3,2),
    gap            numeric(3,2),
    gap_triggered  boolean     not null default false,
    top_prosody    jsonb,
    created_at     timestamptz not null default now(),
    unique (session_id, turn_index)
);

create index idx_turn_session_index on turn_log (session_id, turn_index);
create index idx_turn_occurred      on turn_log (occurred_at);

create table turn_tag (
    turn_id uuid not null references turn_log(id),
    tag     text not null,
    primary key (turn_id, tag)
);

create index idx_turn_tag_tag on turn_tag (tag);
```

| 컬럼 | 규칙 |
| --- | --- |
| `transcript_enc` | **AES-GCM 암호문(base64).** JPA `AttributeConverter`가 변환하므로 애플리케이션 코드는 평문 `String`으로 다룬다(F5-02) |
| `role` | **assistant 턴은 valence·gap이 전부 NULL, 태그 없음**(계약 §3-2). 측정 대상은 사용자 발화뿐 |
| `occurred_at` / `created_at` | 발화 시각 / 적재 시각. `/internal/turns`가 재시도되면 갈린다. **`occurred_at`은 계약 §3-2(v1.5)가 밀리초 정밀도·재시도 불변을 보장**하므로 중복 판별의 기준으로 쓸 수 있다 — `timestamptz`는 마이크로초까지 담아 정밀도 손실이 없다 |
| `unique (session_id, turn_index)` | 같은 턴이 두 번 적재되는 것을 DB가 막는다 — `/internal/turns`가 **3회 재시도**하므로(계약 §3-2 v1.3) 중복이 실제로 발생할 수 있다. **위반 시 `occurred_at`으로 재시도/충돌을 판별한다**(아래) |
| `top_prosody` | 상위 5개까지. 디버깅·재현성 검증용 |
| **음성 원본** | **컬럼이 없다.** 어떤 형태로도 저장하지 않는다(FR-041) |

> `idx_turn_tag_tag`는 F7-02 태그별 집계가 전 기간을 훑기 때문에 필요하다.
> **`unique (session_id, turn_index)` 위반을 무조건 "이미 적재됨"으로 해석하면 안 된다.** 이어하기(F2-07)는 같은 `sessionId`를 유지하므로, AI가 재연결 후 인덱스를 리셋하면 **다른 발화가 같은 인덱스로 들어와 조용히 버려진다.** 그래서 위반 시 **기존 행의 `occurred_at`과 비교한다** — 같으면 재시도(무시하고 202), 다르면 충돌(`max(turn_index)+1`로 저장 + `ops_error_log`의 `TURN_INDEX_COLLISION`, 역시 202). 재시도는 같은 페이로드를 다시 보내고 충돌은 다른 발화이므로 이 한 컬럼으로 갈린다. 상세는 `phase-3-turn-ingest.md` 3-1.
> **`occurred_at`과 `created_at`을 나눠 둔 값어치가 여기서 나온다.** `created_at`은 재시도마다 달라져 판별자가 될 수 없다.
> **⚠️ `occurred_at`은 정확한 발성 시각이 아니다.** AI서버가 자기 UTC 시계로 찍고(user 턴은 분석 직후, assistant 턴은 스트림 종료 시점) **실제 발성보다 수백 ms 뒤**다(계약 §3-2 v1.5). 중복 판별에는 영향이 없지만, **이 값으로 발화 간격·응답 지연을 분석하지 않는다.**

### 개인 baseline (F3-04 · F3-05)

```sql
create table user_baseline (
    profile_id    uuid primary key references profile(id),
    session_count integer     not null default 0,
    avg_gap       numeric(3,2),
    stddev_gap    numeric(3,2),
    updated_at    timestamptz not null default now()
);
```

| 컬럼 | 규칙 |
| --- | --- |
| `session_count` | **5 미만이면 `fixed`, 이상이면 `personal`**(F3-04). 세션 시작 시 읽는다 |
| `avg_gap` `stddev_gap` | 갭이 NULL인 턴은 집계에서 제외(F3-05). 세션이 없으면 NULL |

> **갱신은 증분이 아니라 전체 재계산으로 한다.** 도그푸딩 규모(3인 × 10일)에서 턴 수가 수백 건이라 전체 재계산이 밀리초 단위이고, 세션 삭제(F10-01) 후 재계산과 **같은 코드 경로**를 쓸 수 있다. 증분으로 하면 삭제 경로를 따로 만들어야 하고 표준편차 증분은 부동소수 오차가 누적된다.

### 관찰 (F7)

```sql
create table observation (
    id           uuid primary key default gen_random_uuid(),
    profile_id   uuid        not null references profile(id),
    sentence     text        not null,
    tag          text        not null,
    occurrences  integer     not null,
    tag_avg_gap  numeric(3,2) not null,
    user_avg_gap numeric(3,2) not null,
    ratio        numeric(4,2) not null,
    status       text        not null default 'active' check (status in ('active','invalidated')),
    feedback     text        check (feedback in ('agree','disagree')),
    created_at   timestamptz not null default now()
);

create index idx_observation_profile on observation (profile_id, created_at desc);

create table observation_evidence (
    observation_id uuid not null references observation(id),
    turn_id        uuid not null references turn_log(id),
    primary key (observation_id, turn_id)
);

create index idx_evidence_turn on observation_evidence (turn_id);
```

| 컬럼 | 규칙 |
| --- | --- |
| `tag` `occurrences` `tag_avg_gap` `user_avg_gap` `ratio` | **계약 §2-6의 `evidence` 객체가 이 5개 그대로다** — `tag`가 포함된다. 관찰 문장 ↔ 이 숫자의 불일치는 0건이어야 한다(§1.4) |
| `feedback` | **NULL이 기본**(미응답). `agree`/`disagree` 둘뿐이고 취소·수정 없다(F7-08) |
| `status` | `disagree`가 관찰을 **삭제하지 않는다**(F7-08). 무효화는 F10-02 경로에서만 |

> **`idx_evidence_turn`이 F10-02의 핵심이다.** 턴을 지울 때 "이 턴을 근거로 쓰던 관찰"을 역방향으로 찾아야 하는데, 이 인덱스가 없으면 전체 스캔이 된다.

### 위기 이벤트 (F4-04)

```sql
create table crisis_event (
    id          uuid primary key default gen_random_uuid(),
    profile_id  uuid        not null references profile(id),
    session_id  uuid        not null references voice_session(id),
    detected_by text        not null check (detected_by in ('rule','llm')),
    created_at  timestamptz not null default now()
);

create index idx_crisis_session on crisis_event (session_id);
```

> **`turn_id` 컬럼을 두지 않는다.** turn ID가 있으면 조인 한 번으로 "그때 무슨 말을 했는지"에 도달한다 — 가장 민감한 지점에서 그 경로를 아예 만들지 않는다(spec §6-1). 세션 단위까지만 남겨도 "언제 몇 번 감지됐는지"는 파악된다.
> **발화 내용을 넣지 않는다**(FR-092). `detected_by`는 규칙/LLM 구분일 뿐 매칭된 표현을 담지 않는다.
> `idx_crisis_session`은 세션 삭제(F10-01)와 `/live`의 `crisisDetected` 조회에 쓰인다.

### 운영 로그 (F11-03)

```sql
create table ops_error_log (
    id         uuid primary key default gen_random_uuid(),
    service    text        not null,
    code       text        not null,
    message    text        not null,
    created_at timestamptz not null default now()
);
```

> **탈퇴 삭제 대상이 아니다**(spec §6-1). 사용자 데이터를 담지 않고 장애 분석에 필요하다.
> **`message`에 발화 내용·`sessionId`를 넣지 않는다**(FR-092, 백엔드 절대 원칙 3·6번). 이 테이블이 규칙을 깨기 가장 쉬운 자리다.

#### `sessionRef` — 세션을 안 남기면서 상관시키는 법 (2026-09-04)

발화도 `sessionId`도 못 남기면 **`/internal/turns` 저장이 실패해도 어느 세션의 문제인지 알 수 없다.** 도그푸딩의 목적이 실사용 로그 수집인데, "3일치 턴이 안 쌓였는데 왜인지 모른다"가 되면 되돌릴 방법이 없다.

```
sessionRef = SHA-256(sessionId).hex[:8]
```

- `ops_error_log.message` **앞머리**와 애플리케이션 로그, 계약 §1-2 오류 응답의 `traceId`에 **같은 값**을 쓴다 — 컬럼을 늘리지 않는다
- **원본을 복원할 수 없으므로 절대 원칙 6번을 깨지 않는다.** 그 규칙의 목적은 CLM 인증 수단(`custom_session_id`)의 노출을 막는 것이고, 해시는 인증에 쓸 수 없다
- 같은 세션에서 난 오류끼리 묶인다. 사용자를 특정해야 하면 `voice_session`을 훑어 같은 해시를 만들어 대조한다 — **로그에서 DB로 가는 방향은 열려 있고, 로그만으로는 아무것도 못 한다**

## 삭제 순서 (FK가 `NO ACTION`이므로 코드가 순서를 지킨다)

### F10-01 세션 삭제 — `DELETE /api/sessions/{id}`

계약 §2-11이 **건수와 ID 목록을 응답으로 요구**하므로 각 단계에서 결과를 수집한다.

```
① 영향받는 관찰 수집   SELECT DISTINCT observation_id
                        FROM observation_evidence e JOIN turn_log t ON e.turn_id = t.id
                        WHERE t.session_id = ?
② turn_tag 삭제        WHERE turn_id IN (해당 세션의 turn)
③ observation_evidence 삭제  (같은 조건)
④ turn_log 삭제        WHERE session_id = ?        → deletedTurnCount
⑤ ①의 관찰별 남은 근거 수 재집계
     < 3  → observation 삭제 (evidence 행 먼저)   → removedObservationIds
     ≥ 3  → occurrences·tag_avg_gap·ratio 갱신    → recalculatedObservationIds
⑥ crisis_event 삭제    WHERE session_id = ?        ← 2026-09-04 결정 (spec F10-01에 없던 항목)
⑦ voice_session 삭제
⑧ user_baseline 재계산 (F3-05와 같은 코드)
```

> **①을 ④보다 먼저 하지 않으면 안 된다.** 턴을 지우면 `observation_evidence` 연결이 사라져 "어느 관찰이 영향받았는지"를 알 방법이 없어진다.
> 전 과정이 **단일 트랜잭션**이다. 중간 실패 시 롤백해 "절반만 지워진" 상태를 만들지 않는다.

### F10-03 탈퇴 — `DELETE /api/account`

**10개 테이블, 단일 트랜잭션.** `ops_error_log`는 제외한다.

```
observation_evidence → observation → turn_tag → turn_log → crisis_event
→ voice_session → user_baseline → account_profile → account → profile
```

> 자식부터 부모 순서다. FK가 `NO ACTION`이라 순서를 어기면 제약 위반으로 실패하고 전체가 롤백된다 — **순서 실수가 조용히 넘어가지 않는다는 뜻**이라 오히려 안전하다.
> 수용 기준: 같은 카카오 계정으로 재가입 시 **신규 사용자로 시작**한다(F10-03).

## 마이그레이션 파일

`src/main/resources/db/migration.sql` 하나에 위 DDL을 **테이블 생성 순서대로**(부모 먼저) 담는다.

- 로컬: compose Postgres에 적용 후 애플리케이션 기동 확인 (Phase 1)
- 배포: 같은 파일을 Supabase에 적용 (배포 시점)
- **스키마를 코드로 관리한다** — Supabase 콘솔에서 직접 테이블을 고치지 않는다. 고치면 로컬과 갈라지고, 갈라진 걸 알아채는 시점이 배포 후가 된다
