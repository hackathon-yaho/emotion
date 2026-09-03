# 백엔드 작업 문서

> **수정 기록 (2026-09-03 ②)** — 받은 요청 4건에 회신 완료(api-contract v1.3). 결정 로그에 10건 추가(CLM 인증·sessionId 형식·재시도 3회·요약 동기 생성 등), "받은 요청"을 "회신한 요청"으로 갱신, phase-2·3·5의 ⚠️ 해소, 절대 원칙에 `sessionId` 로깅 금지 추가.
> **수정 기록 (2026-09-03 ①)** — 문서 신설(2026-finance-ai-challenge/backend/docs/README.md의 운영 규칙을 이식).

> 감정 케어 보이스 저널 백엔드의 실행 계획 문서입니다. **여기 적힌 모든 항목은 루트 `../../docs/`의 스펙·계약 문서에 근거가 있으며, 근거 없는 항목은 "미확정"으로 표시했습니다.**

## 이 문서를 쓰는 법

1. 작업을 시작할 때 이 파일에서 현재 Phase를 확인한다.
2. 해당 Phase 문서를 열고 체크리스트를 위에서부터 처리한다.
3. 각 항목에는 **근거 문서 위치**(spec.md F번호, api-contract.md §번호)가 붙어 있다. 구현 중 판단이 필요하면 추론하지 말고 근거 문서를 연다.
4. 근거 문서와 다르게 구현해야 할 상황이 생기면 **근거 문서를 먼저 고치고**(문서 상단 수정 기록에 남기고) 코드를 바꾼다 — 루트 `../../CLAUDE.md` "계약 변경" 규칙.
5. **API를 하나 완료하거나 수정하면 [api-spec.md](api-spec.md)를 같이 고친다** (아래 규칙).
6. **루트 `../../docs/`를 고쳤으면 이 폴더에 반영할 것이 있는지 확인한다** (아래 "역방향 규칙").

## API 작업 규칙 — `api-spec.md`를 항상 최신으로

[api-spec.md](api-spec.md)는 **실제로 무엇이 구현됐는지 보여주는 문서**다. 코드만 바뀌고 이 문서가 그대로면, 다음에 이어받는 사람(미래의 나 포함)이 뭐가 되고 뭐가 안 되는지 알 방법이 없다.

> **API를 하나 완료하거나 수정할 때마다 `api-spec.md`를 같이 고친다.** 커밋 하나에 코드와 문서가 같이 들어간다.

고칠 때 두 곳을 함께 본다.

1. **상단 "구현 현황" 표** — `미구현` → `구현 완료` (계약이 개정된 뒤 구현했으면 `구현 완료 (v1.x 기준)`)
2. **해당 엔드포인트 절** — 실제 동작(계약과 다른 예외 처리, 실제로 쓰는 에러 코드 등)

### 계약 문서와의 관계 (헷갈리지 말 것)

| 문서 | 성격 | 고치는 시점 |
| --- | --- | --- |
| `../../docs/02-architecture/api-contract.md` | **계약** — 앱·AI와 합의한 내용, 단일 출처 | 상대 역할과 **합의 후**, 구현 **전** |
| `api-spec.md` | **구현 현황** — 실제로 동작하는 것 | **구현할 때** |

**두 문서가 다르면 `api-contract.md`가 우선이다.** 계약이 먼저 바뀌고 구현이 따라온다. `api-spec.md`에서 계약에 없는 값을 새로 정하지 않는다 — 정해야 하면 계약을 먼저 고치고, 앱·AI에 영향이 있으면 `../../docs/request/{app,ai}/`로 요청을 보낸다.

> **결정 근거는 여기에 적지 않는다.** "왜 그렇게 정했는지"는 `../../docs/request/*` ↔ `../../docs/response/*` 왕복 문서에 이미 남는다. 아래 결정 로그는 그 결론과 근거 문서 위치만 가리킨다.

## 공용 문서가 바뀌면 이 폴더를 확인한다 (역방향 규칙)

위 규칙이 **"코드 → 문서"** 방향이라면, 이건 **"공용 문서 → 백엔드 문서"** 방향이다. 둘 다 없으면 한쪽이 조용히 낡는다.

> **루트 `../../docs/`의 스펙·계약 문서를 고쳤으면, 같은 작업 안에서 이 폴더의 해당 Phase 문서를 열어 반영할 것이 있는지 확인한다.** 없으면 없는 대로 넘어가되, **확인은 건너뛰지 않는다.**

### 어느 문서를 고치면 어디를 봐야 하나

| 루트 문서 | 확인할 백엔드 문서 |
| --- | --- |
| `spec.md` F1 (계정·세션) | `phase-1-skeleton.md` |
| `spec.md` F2 (음성 대화 — 세션 시작·종료·정리·이어하기) | `phase-2-session.md` |
| `spec.md` F3-04·05, F5, F6-03 (임계값·baseline·로그 적재·태그 저장) | `phase-3-turn-ingest.md` |
| `spec.md` F7 (패턴 발견) | `phase-4-pattern-batch.md` |
| `spec.md` F9, F7-06~08 (대시보드·관찰 조회) | `phase-5-dashboard.md` |
| `spec.md` F10 (데이터 관리) | `phase-6-data-lifecycle.md` |
| `spec.md` F11 (운영), 배포 | `phase-7-ops-deploy.md` |
| `02-architecture/api-contract.md` | **`api-spec.md`** + 해당 엔드포인트의 Phase 문서 |
| `02-architecture/ai-pipeline.md` (내부 계약 관련 부분) | `phase-2-session.md` (`/internal/sessions` 조회 응답, `/internal/summaries` 호출) · `phase-3-turn-ingest.md` (`/internal/turns` 수신) · `phase-4-pattern-batch.md` (`/internal/observations` 호출) |
| `00-context/prd.md` §5 보안·개인정보 | `phase-3-turn-ingest.md`(암호화) · `phase-6-data-lifecycle.md`(삭제) · `phase-7-ops-deploy.md`(로깅) |
| `00-context/spec.md` §11 스코프 컷 순서 | 착수 순서 재검토 시 각 Phase 문서 |

새 결정·확정 사항은 문서 매핑과 별개로 **이 파일의 결정 로그**에 남긴다(근거 문서 위치까지).

### 미결 항목은 Phase 문서에도 표시한다

결정이 안 난 항목(내가 보낸 요청의 회신 대기, **또는 내가 아직 회신하지 않은 요청**)이 있는 동안, **그 항목이 막는 Phase 문서에 `⚠️` 표시를 남긴다.** 표시가 없으면 구현할 때 그냥 지금 규칙대로 짜고 넘어가게 된다 — 나중에 결정이 나도 이미 짠 코드를 다시 뜯어야 한다.

**방향을 헷갈리지 말 것.** `../../docs/request/backend/`에 있는 문서는 **남이 백엔드에게 보낸 요청**이고, 회신은 **백엔드가 `../../docs/response/{요청자}/`에 쓴다.** 백엔드가 남에게 보낸 요청의 회신이 `../../docs/response/backend/`로 들어온다. 2026-09-03 현재 후자는 0건, **전자는 4건 전부 회신 완료** — 아래 "회신한 요청" 참조.

## 문서 목록

| 문서 | 내용 | 언제 보나 |
| --- | --- | --- |
| 이 파일 | 작업 규칙, 스택, 추적 매트릭스, 결정 로그, 회신 대기 현황 | 작업 시작할 때 |
| [api-spec.md](api-spec.md) | **구현 현황 문서** (엔드포인트별 실제 동작) | **API를 완료·수정할 때마다 갱신** |
| `phase-1~7-*.md` | Phase별 실행 체크리스트 | 다음에 뭘 할지 정할 때 |

## Phase 목록

| Phase | 문서 | 내용 |
| --- | --- | --- |
| 1 | [phase-1-skeleton.md](phase-1-skeleton.md) | 프로젝트 골격, Supabase 연결, 헬스체크, 카카오 로그인·JWT (F1) |
| 2 | [phase-2-session.md](phase-2-session.md) | 대화 세션 시작·종료·이어하기, Hume 단기 토큰, 미종료 세션 정리 (F2) |
| 3 | [phase-3-turn-ingest.md](phase-3-turn-ingest.md) | `/internal/turns` 수신, 임계값 모드·baseline, 발화 암호화 저장, 태그 저장 (F3-04·05, F5, F6-03) |
| 4 | [phase-4-pattern-batch.md](phase-4-pattern-batch.md) | 패턴 배치 — 태그 집계·규칙 판정·evidence 부착, `/internal/observations` 호출 (F7) |
| 5 | [phase-5-dashboard.md](phase-5-dashboard.md) | 관찰·트렌드·대화기록 조회 API (F7-06~08, F9) |
| 6 | [phase-6-data-lifecycle.md](phase-6-data-lifecycle.md) | 세션 삭제·관찰 연쇄 무효화·탈퇴 전량 삭제 (F10) |
| 7 | [phase-7-ops-deploy.md](phase-7-ops-deploy.md) | 데모 모드, 오류 로깅, 배포 (F11) |

Phase 순서는 의존 관계 순서다 — Phase 3은 Phase 2의 세션이, Phase 4는 Phase 3의 턴 로그가, Phase 5는 Phase 4의 관찰이 있어야 동작한다. Phase 1(인증)·7(운영)은 나머지와 독립적이라 여유 있을 때 끼워 넣어도 된다.

일정이 밀릴 때 버리는 순서는 `../../docs/00-context/spec.md` §11(스코프 컷 순서)을 단일 기준으로 삼는다. 백엔드가 임의로 순서를 바꾸지 않는다. **F4(위기 감지)는 백엔드가 직접 만들지 않지만(AI서버 담당), 이를 막는 방향의 변경(예: `crisis_event`에 필드 추가 거부)도 하지 않는다.**

## 스택

| 항목 | 값 | 근거 |
| --- | --- | --- |
| 언어·버전 | Java (버전 미확정) | `../README.md` — "Java/Spring Boot"까지만 확정 |
| 프레임워크 | Spring Boot 3.x | `../../docs/00-context/spec.md` 헤더 |
| 빌드 도구 | 미확정 (Gradle/Maven) | — |
| 베이스 패키지명 | 미확정 | — |
| 로컬 인프라 | 미확정 (docker-compose 여부 포함) | — |
| DB | Supabase PostgreSQL | `../../docs/00-context/spec.md` §6-1 |
| 배포 | 미확정 | `../../docs/00-context/prd.md` — 웹 배포·제출 URL 필요, 플랫폼은 미결 |
| 인증 | 카카오 로그인 → 자체 JWT(`Authorization: Bearer`), 만료 7일 | `../../docs/02-architecture/api-contract.md` §1-1 |
| 내부 API 인증 | 공유 시크릿 헤더 | `../../docs/00-context/spec.md` F5-01, api-contract §3-1 |

### 패키지 구조 (제안 — 미확정)

참고할 사내 레퍼런스 프로젝트가 없어 F-그룹 기준으로 도메인을 나눈 초안이다. **팀 결정 전까지 구속력 없음.**

```
(베이스 패키지)
├── auth/          ← F1 카카오 로그인 · JWT
├── session/       ← F2 대화 세션 (시작·종료·이어하기·정리 스케줄러)
├── turn/          ← F3-04·05, F5, F6-03 턴 로그 수신·저장
├── pattern/       ← F7 패턴 배치 (집계·규칙 판정·evidence)
├── dashboard/      ← F9 트렌드·대화기록 조회
├── account/       ← F10 삭제·탈퇴
├── health/        ← F11-02
└── common/
    ├── enums/
    └── global/    ErrorCode.java, dto/ErrorResponse.java,
                   exception/BusinessException.java, handler/GlobalExceptionHandler.java
```

- 오류 응답은 `common/global`의 `ErrorCode` + `GlobalExceptionHandler`로 일원화한다. `../../docs/02-architecture/api-contract.md` §1-2의 오류 코드(`VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `KAKAO_VERIFY_FAILED`, `INTERNAL_AUTH_FAILED`, `FORBIDDEN`, `NOT_FOUND`, `SESSION_NOT_RESUMABLE`, `HUME_TOKEN_ISSUE_FAILED`, `INTERNAL_ERROR`)를 `ErrorCode` enum으로 정의한다.
- **음성 파일을 다루는 코드/패키지를 두지 않는다.** 음성 원본은 앱↔Hume 구간에만 존재한다(FR-041). 루트 `CLAUDE.md` "경계 감시" 참조.

## 요구사항 추적 매트릭스 (백엔드 소관만)

`../../docs/00-context/spec.md` §9 추적 매트릭스의 백엔드(담당 `A`, 또는 `A/B`·`A/C` 중 백엔드 몫) 부분을 Phase에 매핑한 것이다.

| 요구사항 | 기능 ID | Phase |
| --- | --- | --- |
| FR-001~003 (카카오 로그인·JWT·탈퇴) | F1-01, F1-02, F1-04 | 1 |
| FR-010~013 (세션 시작·Hume 단기 토큰) | F2-01 | 2 |
| **FR-014 (미종료 세션 정리)** | **F2-06** | 2 |
| **FR-015 (중단 세션 이어하기, P1)** | **F2-07** | 2 |
| FR-023 (임계값 모드) | F3-04, F3-05 | 3 |
| FR-040~042 (턴 로그 적재·암호화) | F5-01~04 | 3 |
| FR-043 (태그 저장) | F6-03 | 3 |
| FR-050~054 (패턴 배치·규칙 판정·evidence) | F7-01~05 | 4 |
| FR-055 (관찰 근거 열람) | F7-06, F7-07 | 5 |
| **FR-056 (관찰 피드백, P1)** | **F7-08** | 5 |
| FR-070~073 (대시보드) | F9-01~05 | 5 |
| FR-080·081 (세션 삭제·연쇄 무효화) | F10-01, F10-02 | 6 |
| FR-003 (탈퇴 전량 삭제) | F10-03 | 6 |
| FR-090 (데모 모드) | F11-01 | 7 |
| NFR-08 (오류 로깅) | F11-02, F11-03 | 1, 7 |
| NFR-06 (세션당 원가 상한 — 이어하기 잔여 시간 승계) | F2-03, F2-07 | 2 |

F3(측정)·F4(안전)·F7-04(문장화)·F8(제안)의 판정·생성 로직은 **AI서버(B) 소관**이다. 백엔드는 그 결과를 받아 저장·조회하는 쪽만 만든다.

## 절대 원칙 (구현 중 어떤 경우에도 깨지 않는다)

루트 `../../CLAUDE.md` "절대 규칙" 표가 단일 출처다. 그중 **백엔드 코드가 직접 깨뜨릴 수 있는 것**만 다시 짚는다 — 매번 열어보지 않아도 반사적으로 걸리게.

1. **관찰 생성 판정(F7-03)에 LLM 호출을 섞지 않는다.** `occurrences >= 3 AND tagAvgGap >= userAvgGap × 1.5`는 결정적 규칙 엔진이다. — FR-051·052
2. **`crisis_event`에 `turn_id`를 두지 않는다.** 세션 단위까지만 남긴다. — `../../docs/00-context/spec.md` §6-1
3. **로그·오류에 발화 내용(`transcript`)을 남기지 않는다.** `ops_error_log`·`crisis_event` 포함. — FR-092
4. **음성 파일을 수신·저장하지 않는다.** 백엔드에는 오디오 관련 코드/필드가 존재하지 않는다. — FR-041
5. **Hume API 키를 앱에 내려주지 않는다.** 단기 액세스 토큰만 발급한다. — FR-013
6. **`sessionId`를 로그에 남기지 않는다.** CLM 인증 수단(§3-4)이 되어 비밀과 동급이다. — `api-contract.md` §1-1, v1.3

## 결정 로그

착수 전 확정이 필요하다고 스펙 문서가 표시했던 항목, 또는 구현 중 판단이 필요해 정리해 둔 항목의 결론이다.

### 확정

| 항목 | 결정 | 반영한 문서 | 근거 (왜 이렇게 정했나) |
| --- | --- | --- | --- |
| 임계값 모드 전환 기준 | `session_count < 5` → `fixed`, `>= 5` → `personal`(개인 평균 ± 표준편차) | `spec.md` F3-04 | 고정 단독은 목소리가 원래 낮은 사용자에게 매번 오탐. 개인 baseline 단독은 첫 사용자 데모가 작동하지 않음 |
| 미종료 세션 정리 주기 | 시작 후 **30분** 경과 → `timeout` 종료 + 배치 큐 적재. F11-02 헬스체크와 같은 스케줄러 | `spec.md` F2-06 | 추가 인프라 없이 중단된 대화의 배치 유실을 막음 |
| 새 세션 시작 시 동시 세션 처리 | 새 세션 시작(F2-01) 시 그 사용자의 열린 세션을 먼저 닫는다 | `spec.md` F2-06 | 별도 잠금 로직 없이 동시 세션 문제를 해결 |
| 이어하기 창 | 중단 후 **30분** (F2-06 정리 시간과 동일값) | `spec.md` F2-07 | 규칙을 하나로 유지 |
| 이어하기 잔여 시간 | `hardCutSec − usedSec`. 새 7분을 지급하지 않는다 | `spec.md` F2-07 | 세션당 원가 상한 $0.49(NFR-06)가 이어하기로 뚫리면 안 됨 |
| `crisis_event` 스키마 | `turn_id` 없음. 세션 단위까지만 | `spec.md` §6-1 | 위기 발화라는 가장 민감한 지점에서 "그때 무슨 말을 했는지"로 가는 조인 경로 자체를 만들지 않음 |
| `ops_error_log` 탈퇴 삭제 대상 여부 | **제외.** 나머지 10개 테이블만 탈퇴 시 삭제 | `spec.md` §6-1, F10-03 | 사용자 데이터를 담지 않고(발화 내용 미포함) 장애 분석에 필요 |
| 인증 방식 | 카카오 토큰 검증 후 자체 JWT 발급, `Authorization: Bearer`, 만료 7일 | `api-contract.md` §1-1 | 매일 쓰는 앱이라 짧은 만료는 재로그인 이탈 요인 |
| 내부 API 인증 | 공유 시크릿 헤더 (AI서버 → 백엔드 `/internal/turns`, `/internal/observations`) | `api-contract.md` §3-1, spec F5-01 | — |
| 관찰-evidence 연쇄 무효화 기준 | 근거 turn 삭제 시, **남은 근거가 3회 미만이면 관찰 삭제**, 이상이면 evidence 숫자 재계산 | `spec.md` F10-02 | 근거를 잃은 관찰이 "근거 없는 문장"으로 남는 것을 방지 — §1.4 "불일치 0건" 지표와 직결 |
| 위기 판정 결합 방식 | **규칙 OR LLM.** LLM 호출 실패에도 키워드 규칙은 단독 동작 | `spec.md` F4-02·03 (AI서버 구현이지만 백엔드가 받는 `crisis` 필드 스키마에 영향) | 재현율 우선 정책 |
| `sessionId` 형식 | **UUIDv4, 접두사 없음** (Postgres `uuid` 컬럼) | `api-contract.md` §1-1, v1.3 | CLM 인증 수단이 되므로 엔트로피 필요. UUID는 표준 라이브러리라 코드 0줄 |
| CLM 인증 | **`custom_session_id`를 §3-4로 검증.** `language_model_api_key`는 미사용(앱이 들면 웹 번들 노출) | `api-contract.md` §4, v1.3 | FR-013·NFR-04가 Hume 키에 대해 막은 것과 같은 문제가 CLM 키에서 재발하는 것을 막음 |
| `GET /internal/sessions/{id}` 조회 실패 처리 | **fail-closed.** 캐시 히트만 백엔드 상태 무관 통과, 캐시 미스+5xx/타임아웃은 401 | `api-contract.md` §3-4, v1.3 | 백엔드가 죽으면 `session/start`도 죽어 새 세션 자체가 안 생김 — fail-closed로 잃는 가용성이 없음 |
| `recentObservations` 포함 여부 | **지금 넣는다** (§3-4 응답) | `api-contract.md` §3-4, v1.3 | F8을 실제로 만들 때 계약을 또 고치는 왕복을 아낌 |
| `humeConfigId` 발급 실패 처리 | **기동 시 fail-fast.** 환경변수 누락이면 서버가 안 뜬다 — 런타임 503이 아니다 | `api-contract.md` §2-4, v1.3 | 환경변수 값에는 "발급 실패"가 없음. 설정 누락을 런타임 장애로 위장하지 않음 |
| 대화 중 턴 신호 전달 수단 | **폴링** (SSE 아님), 간격은 `session/start`가 `livePollIntervalSec`로 내려줌 | `api-contract.md` §2-13, v1.3 | `/internal/turns`가 fire-and-forget이라 SSE로도 유실은 못 덮음. 폴링은 늦은 턴을 다음 주기에 회수 |
| 비데모 계정의 valence·갭 마스킹 | **`turns: []`.** `null`로 막지 않는다 | `api-contract.md` §2-13, v1.3 | `null`을 마스킹에 쓰면 §1-3 "측정 못함"과 뜻이 충돌 |
| `/internal/turns` 재시도 | **1회 → 3회**(백오프), 전 세션 동일 정책 | `api-contract.md` §3-2, v1.3 | 데모 계정 전용 분기는 무대에서 처음 도는 코드가 됨 |
| 세션 요약 생성 | **동기 호출(3초), `endReason: timeout`은 미호출** | `api-contract.md` §3-5, v1.3 | spec F2-05 수용 기준이 "S02-1에 요약 표시". 스케줄러 정리는 건당 대기 없음 |
| 계약 개정 단위 | **v1.3 한 번에 묶는다** (부분 적용 안 함) | `api-contract.md` §6 | `sessionId` 형식 하나가 4개 절에 걸쳐 있어 쪼개면 중간 버전에서 예시가 어긋남 |

### 회신한 요청 (2026-09-03, 4건 전부 ✅)

회신은 백엔드가 `../../docs/response/{요청자}/`에 **요청과 같은 파일명**으로 썼다. 요청 본문은 고치지 않고 요청 문서의 상태 배너만 ✅로 바꿨다. 네 건 모두 계약서를 **v1.3 하나로 묶어** 개정했다.

| 요청 | 회신 | 반영 |
| --- | --- | --- |
| [`hume-config-id.md`](../../docs/request/backend/hume-config-id.md) | [`response/app/hume-config-id.md`](../../docs/response/app/hume-config-id.md) | `humeConfigId` 필드 추가 (기동 시 fail-fast) |
| [`session-context-lookup.md`](../../docs/request/backend/session-context-lookup.md) | [`response/ai/session-context-lookup.md`](../../docs/response/ai/session-context-lookup.md) | §3-4 신설, CLM 인증 확정, `sessionId` UUID화 |
| [`live-turn-signal.md`](../../docs/request/backend/live-turn-signal.md) | [`response/app/live-turn-signal.md`](../../docs/response/app/live-turn-signal.md) | §2-13 신설(폴링), 재시도 3회 |
| [`session-summary-endpoint.md`](../../docs/request/backend/session-summary-endpoint.md) | [`response/ai/session-summary-endpoint.md`](../../docs/response/ai/session-summary-endpoint.md) | §3-5 신설(동기 3초) |

### 백엔드가 보낸 요청

**없음** (2026-09-03). `../../docs/response/backend/`가 비어 있는 것은 정상이다.

## 스펙 문서에서 발견한 불일치

구현 전에 알고 있어야 할, 문서 간 어긋난 지점을 적는다. **발견 즉시 이 표에 추가하고, 해소되면 "해소 (날짜)"로 표시를 바꾼다** (지우지 않는다 — 왜 헷갈렸는지가 기록이다).

| 지점 | 내용 | 처리 |
| --- | --- | --- |
| (현재 없음) | — | — |
