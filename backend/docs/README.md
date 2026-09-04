# 백엔드 작업 문서

> **수정 기록 (2026-09-04 ⑥)** — **계약 v1.4 개정 + 이 폴더 전면 대조.** 루트 스펙과 Phase 문서를 전수 대조해 **공백·결함 11건**을 찾아 고쳤다. 큰 것 넷 — ① **미회신 요청 1건을 놓치고 있었다**(`tag-gap-endpoint.md`, ⑤ 작성 이후 도착) → 회신 완료, `GET /api/trend`에 `tagGaps`·`userAvgGap` ② **`highlights`(F9-02)의 판정 임계값이 DB에 없었다** → `voice_session.gap_threshold` 신설 ③ **이어하기 + 3회 재시도가 만나면 턴이 조용히 유실된다** → 계약 §3-2 채번 규칙·§3-4 `lastTurnIndex`, AI에 확인 요청(⏳) ④ **F3-04가 `avg_gap` NULL을 안 본다** → 가드 추가, `session_count`를 F3-05에서 분리. 아울러 **Phase 문서의 응답 필드 나열을 전부 걷어내고 계약 §번호만 가리키게 했다**(부분 복제가 5곳에서 어긋나 있었다 — `api-spec.md`에 이미 적용한 규칙을 여기에도 적용). `/live`를 Phase 5 → Phase 3으로, 데모 플래그는 `profile.demo_mode` 컬럼으로. 결정 로그 6건 추가.
>
> **수정 기록 (2026-09-04 ⑤)** — **Phase 문서 7개를 해빙 밀도로 재작성 + [`data-model.md`](data-model.md) 신설.** 종전 Phase 문서는 근거만 달린 한 줄 체크리스트(16~36줄)라 실행 문서로 얇았다 — 해빙의 `README.md`만 이식하고 `phase-*.md`를 안 봤던 탓이다. 목표·하위 절·실행 단위 체크박스·각 항목의 근거·미래 Phase 대비·**이 Phase에서 하지 않는 것**을 채웠다. 결정 4건 추가(삭제 정책·`crisis_event`·배치 트리거·`api-spec` 범위). **작성 중 spec 공백 3건 발견** — `turn_log.role`·`occurred_at` 누락, F10-01의 `crisis_event` 처리 누락 → spec 개정.
>
> **수정 기록 (2026-09-04 ④)** — **착수 블로커 6건 전부 결정.** 스택 표의 미확정 5건을 확정값으로 교체(해빙 설정 복제 + `com.hackathonyaho.voicejournal`), 패키지 구조를 "제안"에서 확정으로 올리고 **인터페이스+`Impl` 생략**을 명시, 결정 로그 7건 추가. **PRD §12가 v1.1로 개정돼 9/10이 목표로 내려갔고 배포는 세 파트 확인 후로 결정**되어 `roadmap.md`를 의존 순서 중심으로 재작성했다. 통합 테스트 도달 문제로 `request/ai/integration-test-path.md` 신설(⏳). 아래 불일치 표의 포트 항목 해소.
>
> **수정 기록 (2026-09-04 ③)** — **`roadmap.md` 신설.** PRD §12 일정 상수에서 9/10 도그푸딩 최소 조건을 역산해 Phase 1~7을 두 마감(9/10·9/20)으로 재배치했다. 발견 2건 — ① v1.3 fail-closed 회신 때문에 **`GET /internal/sessions/{id}`가 도그푸딩 P0로 올라갔다**(없으면 CLM이 401로 막힘) ② **Phase 7의 배포 항목만 9/10 앞으로 당겨진다**(앱이 붙을 주소가 필요). 아래 불일치 표에 백엔드 로컬 포트 불일치(앱 8080 / AI 8000) 추가.
>
> **수정 기록 (2026-09-03 ②)** — 받은 요청 4건에 회신 완료(api-contract v1.3). 결정 로그에 10건 추가(CLM 인증·sessionId 형식·재시도 3회·요약 동기 생성 등), "받은 요청"을 "회신한 요청"으로 갱신, phase-2·3·5의 ⚠️ 해소, 절대 원칙에 `sessionId` 로깅 금지 추가.
>
> **수정 기록 (2026-09-03 ①)** — 문서 신설(2026-finance-ai-challenge/backend/docs/README.md의 운영 규칙을 이식).

> 감정 케어 보이스 저널 백엔드의 실행 계획 문서입니다. **여기 적힌 모든 항목은 루트 `../../docs/`의 스펙·계약 문서에 근거가 있으며, 근거 없는 항목은 "미확정"으로 표시했습니다.**

## 이 문서를 쓰는 법

1. 작업을 시작할 때 이 파일에서 현재 Phase를 확인한다.
2. 해당 Phase 문서를 열고 체크리스트를 위에서부터 처리한다.
3. 각 항목에는 **근거 문서 위치**(spec.md F번호, api-contract.md §번호)가 붙어 있다. 구현 중 판단이 필요하면 추론하지 말고 근거 문서를 연다.
4. 근거 문서와 다르게 구현해야 할 상황이 생기면 **근거 문서를 먼저 고치고**(문서 상단 수정 기록에 남기고) 코드를 바꾼다 — 루트 `../../CLAUDE.md` "계약 변경" 규칙.
   - **요청·응답 스키마는 이 폴더 어디에도 복제하지 않는다.** Phase 문서는 계약 §번호를 가리키기만 하고, 여기 적는 것은 **계약에 없는 백엔드 고유 판단**(갭 NULL 턴 제외, 중복 적재는 202, 비데모는 `turns: []` 등)뿐이다 — 2026-09-04 결정. 부분 복제가 실제로 5곳에서 어긋났다.
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
| `spec.md` F3-04·05, F5, F6-03 (임계값·baseline·로그 적재·태그 저장) · **F4-04·F11-01의 `/live`** | `phase-3-turn-ingest.md` |
| `spec.md` F7 (패턴 발견) | `phase-4-pattern-batch.md` |
| `spec.md` F9, F7-06~08 (대시보드·관찰 조회) | `phase-5-dashboard.md` |
| `spec.md` F10 (데이터 관리) | `phase-6-data-lifecycle.md` |
| `spec.md` F11 (운영), 배포 | `phase-7-ops-deploy.md` (데모 플래그 분기는 `phase-3`) |
| `02-architecture/api-contract.md` | **`api-spec.md`** + 해당 엔드포인트의 Phase 문서 |
| `02-architecture/ai-pipeline.md` (내부 계약 관련 부분) | `phase-2-session.md` (`/internal/sessions` 조회 응답, `/internal/summaries` 호출) · `phase-3-turn-ingest.md` (`/internal/turns` 수신) · `phase-4-pattern-batch.md` (`/internal/observations` 호출) |
| `00-context/prd.md` §5 보안·개인정보 | `phase-3-turn-ingest.md`(암호화) · `phase-6-data-lifecycle.md`(삭제) · `phase-7-ops-deploy.md`(로깅) |
| `00-context/spec.md` §11 스코프 컷 순서 | 착수 순서 재검토 시 각 Phase 문서 |

새 결정·확정 사항은 문서 매핑과 별개로 **이 파일의 결정 로그**에 남긴다(근거 문서 위치까지).

### 미결 항목은 Phase 문서에도 표시한다

결정이 안 난 항목(내가 보낸 요청의 회신 대기, **또는 내가 아직 회신하지 않은 요청**)이 있는 동안, **그 항목이 막는 Phase 문서에 `⚠️` 표시를 남긴다.** 표시가 없으면 구현할 때 그냥 지금 규칙대로 짜고 넘어가게 된다 — 나중에 결정이 나도 이미 짠 코드를 다시 뜯어야 한다.

**방향을 헷갈리지 말 것.** `../../docs/request/backend/`에 있는 문서는 **남이 백엔드에게 보낸 요청**이고, 회신은 **백엔드가 `../../docs/response/{요청자}/`에 쓴다.** 백엔드가 남에게 보낸 요청의 회신이 `../../docs/response/backend/`로 들어온다. 2026-09-04 현재 **받은 요청 5건은 전부 회신 완료**, **백엔드가 보낸 요청 2건은 회신 대기** — 아래 두 절 참조.

## 문서 목록

| 문서 | 내용 | 언제 보나 |
| --- | --- | --- |
| 이 파일 | 작업 규칙, 스택, 추적 매트릭스, 결정 로그, 회신 현황 | 작업 시작할 때 |
| [roadmap.md](roadmap.md) | **착수 계획** — 의존 순서, Phase별 성격, 착수 블로커 | **지금 무엇을 먼저 할지 정할 때** |
| [data-model.md](data-model.md) | **스키마 단일 출처** — 11테이블 DDL·인덱스·FK·삭제 순서 | 테이블을 만들거나 삭제 로직을 짤 때 |
| [api-spec.md](api-spec.md) | **구현 현황 문서** (엔드포인트별 실제 동작) | **API를 완료·수정할 때마다 갱신** |
| `phase-1~7-*.md` | Phase별 실행 문서 (목표·절차·완료 기준·하지 않는 것) | 그 Phase를 실제로 구현할 때 |

## Phase 목록

| Phase | 문서 | 내용 |
| --- | --- | --- |
| 1 | [phase-1-skeleton.md](phase-1-skeleton.md) | 프로젝트 골격, docker-compose, **DB 스키마 11테이블 전부**, 헬스체크·스케줄러 뼈대, 카카오 로그인·JWT (F1) |
| 2 | [phase-2-session.md](phase-2-session.md) | 대화 세션 시작·종료·이어하기, Hume 단기 토큰, 미종료 세션 정리 (F2) |
| 3 | [phase-3-turn-ingest.md](phase-3-turn-ingest.md) | `/internal/turns` 수신, 임계값 모드·baseline, 발화 암호화 저장, 태그 저장, **`GET /api/session/{id}/live`** (F3-04·05, F4-04, F5, F6-03, F11-01) |
| 4 | [phase-4-pattern-batch.md](phase-4-pattern-batch.md) | 패턴 배치 — 태그 집계·규칙 판정·evidence 부착, `/internal/observations` 호출 (F7) |
| 5 | [phase-5-dashboard.md](phase-5-dashboard.md) | 관찰·트렌드(`highlights`·`tagGaps` 포함)·대화기록 조회 API (F7-06~08, F9) |
| 6 | [phase-6-data-lifecycle.md](phase-6-data-lifecycle.md) | 세션 삭제·관찰 연쇄 무효화·탈퇴 전량 삭제 (F10) |
| 7 | [phase-7-ops-deploy.md](phase-7-ops-deploy.md) | 데모 모드, 오류 로깅, 배포 (F11) |

Phase 순서는 의존 관계 순서다 — Phase 3은 Phase 2의 세션이, Phase 4는 Phase 3의 턴 로그가, Phase 5는 Phase 4의 관찰이 있어야 동작한다.

**어느 것을 먼저 하는지는 [roadmap.md](roadmap.md)가 단일 출처다.** 요지만 옮기면 — **Phase 1·2·3이 서야** 턴 로그가 쌓이기 시작하고 앱·AI가 동시에 풀린다. Phase 4~6은 배치가 과거 턴을 다시 읽으므로 나중에 붙여도 이미 쌓인 데이터에 소급 적용된다. **배포(Phase 7)는 세 파트의 기능 확인이 끝난 뒤이며**(PRD §12, 2026-09-04 팀 결정), 그 시점이 곧 도그푸딩 시작 시점이다.

일정이 밀릴 때 버리는 순서는 `../../docs/00-context/spec.md` §11(스코프 컷 순서)을 단일 기준으로 삼는다. 백엔드가 임의로 순서를 바꾸지 않는다. **F4(위기 감지)는 백엔드가 직접 만들지 않지만(AI서버 담당), 이를 막는 방향의 변경(예: `crisis_event`에 필드 추가 거부)도 하지 않는다.**

## 스택

**전부 2026-09-04 확정.** 해빙(`2026-finance-ai-challenge`) 백엔드 설정을 복제했다 — 같은 사람이 최근 돌려본 설정이라 빌드·배포에서 처음 만나는 문제가 없다.

| 항목 | 값 | 근거 |
| --- | --- | --- |
| 언어·버전 | **Java 21** (toolchain) | 해빙 `build.gradle` 복제 |
| 프레임워크 | **Spring Boot 3.4.5** | 같음 |
| 빌드 도구 | **Gradle (Groovy `build.gradle`)** | 같음 |
| 베이스 패키지명 | **`com.hackathonyaho.voicejournal`** (group `com.hackathonyaho`) | 앱 Android 패키지 `com.hackathonyaho.voice_journal`과 계열 일치 |
| 로컬 인프라 | **docker-compose Postgres 16** (해빙 compose 복제) | 개발 데이터가 도그푸딩 로그에 닿지 않게 물리적 분리 — PRD §12 데이터 원칙 |
| DB (배포) | Supabase PostgreSQL | `../../docs/00-context/spec.md` §6-1 |
| 스키마 관리 | **`ddl-auto: none` + `db/migration.sql`** | 해빙 방식. 같은 PostgreSQL이라 로컬·배포에 동일 적용 |
| 서버 포트 | **`server.port: ${PORT:8080}`** | 해빙 `application.yml`. Render가 `PORT`를 주입 |
| 배포 | **Render Free + cron 10분 킵얼라이브**, AI서버와 **별도 계정** | 750시간은 워크스페이스당. 시점은 세 파트 확인 후 — [roadmap.md](roadmap.md) |
| 발화 암호화 | **앱 레벨 AES-GCM + JPA `AttributeConverter`**, 키는 환경변수 | F5-02. pgcrypto는 키가 SQL로 흘러 방어가 반감 |
| 인증 | 카카오 로그인 → 자체 JWT(`Authorization: Bearer`), 만료 7일 | `../../docs/02-architecture/api-contract.md` §1-1 |
| 내부 API 인증 | 공유 시크릿 헤더 `X-Internal-Secret` | `../../docs/00-context/spec.md` F5-01, api-contract §3-1 |

### 패키지 구조 (2026-09-04 확정)

도메인별 최상위 패키지 + 도메인 안에 계층. **해빙과 달리 서비스는 인터페이스+`Impl` 쌍을 만들지 않는다** — 구현이 하나뿐인 인터페이스는 파일만 2배가 되고 교체 시점이 오지 않는다. 필요해지면 그때 추출한다.

```
com.hackathonyaho.voicejournal
├── auth/          ← F1 카카오 로그인 · JWT
├── session/       ← F2 대화 세션 (시작·종료·이어하기·정리 스케줄러)
├── turn/          ← F3-04·05, F5, F6-03 턴 로그 수신·저장
├── pattern/       ← F7 패턴 배치 (집계·규칙 판정·evidence)
├── dashboard/     ← F9 트렌드·대화기록 조회
├── account/       ← F10 삭제·탈퇴
├── health/        ← F11-02
└── common/
    ├── enums/
    └── global/    ErrorCode.java, dto/ErrorResponse.java,
                   exception/BusinessException.java, handler/GlobalExceptionHandler.java
```

- 도메인 안은 `controller/` · `dto/request/` `dto/response/` · `entity/` · `repository/` · `service/`. **서비스는 클래스 하나**(`SessionService.java`)로 둔다.
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
| FR-023 (임계값 모드) | F3-04 | 3 |
| **FR-023 (baseline 갱신, P1 · 스코프 컷 7번)** | **F3-05** | 3 |
| FR-030·031 (대화 중 신호 · 갭 비노출) | F4-04, F11-01 (`/live`) | 3 |
| FR-040~042 (턴 로그 적재·암호화) | F5-01~04 | 3 |
| FR-043 (태그 저장) | F6-03 | 3 |
| FR-050~054 (패턴 배치·규칙 판정·evidence) | F7-01~05 | 4 |
| FR-055 (관찰 근거 열람) | F7-06, F7-07 | 5 |
| **FR-056 (관찰 피드백, P1)** | **F7-08** | 5 |
| FR-070·071·073 (두 선 그래프·갭 구간 강조·대화 기록) | F9-01, **F9-02**(`highlights` — 서버가 계산, 담당 `A/C`), F9-04, F9-05 | 5 |
| **FR-072 (태그별 갭 비교, P1 · 스코프 컷 2번)** | **F9-03** (`tagGaps`·`userAvgGap`, 계약 v1.4) | 5 |
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
   - 대신 **`sessionRef = SHA-256(sessionId)[:8]`**을 남긴다(`data-model.md`). 원본을 복원할 수 없어 인증에 쓸 수 없으므로 이 규칙을 깨지 않으면서, 같은 세션의 오류끼리 묶인다. **아무것도 안 남기면 `/internal/turns` 실패를 추적할 수단이 0이다.**

## 결정 로그

착수 전 확정이 필요하다고 스펙 문서가 표시했던 항목, 또는 구현 중 판단이 필요해 정리해 둔 항목의 결론이다.

### 확정

| 항목 | 결정 | 반영한 문서 | 근거 (왜 이렇게 정했나) |
| --- | --- | --- | --- |
| 임계값 모드 전환 기준 | `session_count < 5` → `fixed`, `>= 5` → `personal`(개인 평균 ± 표준편차) | `spec.md` F3-04 | 고정 단독은 목소리가 원래 낮은 사용자에게 매번 오탐. 개인 baseline 단독은 첫 사용자 데모가 작동하지 않음 |
| 미종료 세션 정리 주기 | 시작 후 **30분** 경과 → `timeout` 종료(그대로 배치 미처리 상태가 된다). F11-02 헬스체크와 같은 스케줄러 | `spec.md` F2-06 | 추가 인프라 없이 중단된 대화의 배치 유실을 막음 |
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
| 프로젝트 골격 (2026-09-04) | **해빙 백엔드 설정 복제** — Java 21 · Boot 3.4.5 · Gradle Groovy · temurin Dockerfile · `${PORT:8080}` · `ddl-auto: none` | 이 파일 스택 표 | 같은 사람이 최근 돌려본 설정이라 빌드·배포에서 처음 만나는 문제가 없다. 골격 세우는 시간을 Phase 2·3으로 넘긴다 |
| 베이스 패키지명 (2026-09-04) | **`com.hackathonyaho.voicejournal`** | 같은 표 | 앱 Android 패키지가 이미 `com.hackathonyaho.voice_journal`이라 계열을 맞춤 |
| 로컬 개발 DB (2026-09-04) | **docker-compose Postgres 16.** 배포는 Supabase | 같은 표 | 같은 DB를 쓰면 개발·테스트 쓰기가 도그푸딩 로그에 섞인다. PRD §12가 "발표 근거는 실사용 로그만"으로 못박은 지점이고, F10-02 연쇄 무효화 때문에 사후 삭제도 위험 |
| 배포 플랫폼·시점 (2026-09-04) | **Render Free + cron 10분 킵얼라이브**, AI서버와 별도 계정. **세 파트 기능 확인 후 배포** | `roadmap.md`, PRD §12 | 750시간은 워크스페이스당이라 계정을 나누면 각각 750시간. 배포 시점은 팀 결정 |
| 9/10 위상 (2026-09-04) | **일정 상수 → 팀 내부 목표.** 고정 마감은 9/20 제출 하나 | PRD §12 (v1.1로 개정) | 팀 결정. 대가(로그 기간 단축 → FR-051 미달 → S03 빈 화면)를 §12에 함께 명시 |
| 발화 암호화 (2026-09-04) | **앱 레벨 AES-GCM + JPA `AttributeConverter`**, 키는 환경변수 | 같은 표, `phase-3-turn-ingest.md` | `javax.crypto`는 JDK 내장이라 의존성 0, 엔티티는 `String`으로 두고 나머지 코드 무수정. pgcrypto는 키가 SQL 쿼리로 흘러 DB 유출을 가정한 방어가 반감된다 |
| 서비스 인터페이스 (2026-09-04) | **인터페이스+`Impl` 쌍을 만들지 않는다.** 클래스 하나 | 같은 표 | 구현이 하나뿐인 인터페이스는 파일만 2배. 해빙과 다른 유일한 지점 |
| 삭제 정책 (2026-09-04) | **FK는 전부 명시하되 `ON DELETE NO ACTION`.** 삭제 순서는 애플리케이션이 정한다 | `data-model.md` | 계약 §2-11이 `deletedTurnCount`·`removedObservationIds` 등 **건수를 응답으로 요구**한다. CASCADE는 조용히 지워 셀 수가 없다. F10-02의 "3회 미만 삭제 / 이상 재계산"도 조건부라 DB 제약으로 표현 불가 |
| `crisis_event` 세션 삭제 (2026-09-04) | **세션 삭제 시 함께 삭제**한다 | `data-model.md`, `spec.md` F10-01(개정) | 탈퇴 삭제 대상 10테이블에 이미 포함된 사용자 데이터이고, F10-01 수용 기준이 "어디에도 남지 않는다"이다. **spec에 이 처리가 없어 그대로 구현하면 FK 위반으로 세션 삭제가 실패한다** |
| 배치 트리거 (2026-09-04) | **`voice_session.pattern_processed_at` + 기존 스케줄러 스캔.** 인메모리 큐·전용 큐 테이블 모두 미채택 | `data-model.md`, `phase-4` | 인메모리 큐는 Render 슬립·재배포에 증발하고, **그 세션은 관찰이 영영 안 생기는데 아무도 모른다.** F2-06이 "추가 인프라 0"으로 만든 선례를 재사용 |
| `api-spec.md` 범위 (2026-09-04) | **구현 현황 표 + 계약과 달라진 부분만.** 요청·응답 스키마를 복제하지 않는다 | 이 파일 "API 작업 규칙" | `api-contract.md`가 3자 계약이라 복제하면 개정 때 두 곳이 어긋난다. 해빙은 `api-spec.md`를 프론트용 명세서로 썼지만 감정은 계약서가 그 역할을 겸한다 |
| **Phase 문서의 스키마 복제 (2026-09-04 ⑥)** | **`api-spec.md`와 같은 규칙을 적용.** 필드 나열을 걷어내고 계약 §번호만 가리킨다. **계약에 없는 백엔드 고유 판단만 남긴다** | 이 파일 "이 문서를 쓰는 법" 4번 | 규칙이 `api-spec.md`에만 있어 Phase 문서는 부분 복제를 했고, **실제로 5곳이 어긋났다** — `evidence`를 4키로 적음(계약은 `tag` 포함 5키), `GET /api/observations`의 `total`·`feedback` 누락, `POST /api/auth/kakao`의 `expiresAt` 누락, `GET /api/trend`가 계약이 아닌 spec 표현을 베껴 3필드 누락, `GET /api/sessions/{id}` 상단 4필드 누락 |
| **`highlights` 판정 기준 (2026-09-04 ⑥)** | **`voice_session.gap_threshold` 스냅샷.** 현재 설정값으로 소급 판정하지 않는다 | `api-contract.md` §2-8 (v1.4), `spec.md` F9-02·§6-1, `data-model.md` | 임계값은 PRD §14-5로 **반드시 한 번 바뀐다.** 현재값으로 판정하면 바꾸는 순간 과거 날짜의 음영이 통째로 달라져, 그날 실제로 되물었던 근거(FR-022)와 화면이 어긋난다 |
| **`tagGaps` 응답 형태 (2026-09-04 ⑥)** | `GET /api/trend`에 필드 추가(별도 엔드포인트 아님). **`range` 종속 · 3회 미만 필터는 서버 · `tagAvgGap` 내림차순 상위 7개.** `userAvgGap`은 전 기간 | `api-contract.md` §2-8 (v1.4), `response/app/tag-gap-endpoint.md` | S04가 이미 하는 호출이라 왕복이 늘지 않는다. 필터를 서버가 하면 F7-03의 3회 기준이 한 곳에만 남는다. `userAvgGap`이 전 기간인 이유는 관찰의 `evidence.userAvgGap`과 같은 값이어야 §1.4 불일치 0건이 성립하기 때문 |
| **`turnIndex` 채번 (2026-09-04 ⑥)** | **AI서버가 채번하되 이어하기 재연결 후 이어 붙인다.** 백엔드는 `/internal/sessions`로 `lastTurnIndex`를 준다 | `api-contract.md` §3-2·§3-4 (v1.4), `request/ai/turn-index-numbering.md` (⏳) | v1.3의 두 결정(재시도 3회 · 이어하기가 같은 `sessionId` 유지)이 교차 검토되지 않았다. **중복 방어(`unique(session_id, turn_index)` → 202)가 유실 장치로 뒤집힌다** — 인덱스를 리셋하면 이후 턴이 전부 "이미 적재됨"으로 조용히 버려진다. 백엔드가 채번하면 중복 방어가 무너져 재시도마다 같은 턴이 3번 저장된다 |
| **F3-04 가드 · `session_count` 소유 (2026-09-04 ⑥)** | 조건을 **`session_count >= 5` AND `avg_gap IS NOT NULL`**로. **`session_count` 증가는 F3-05가 아니라 세션 종료의 기본 동작** | `spec.md` F3-04·F3-05 | 조건이 세션 수뿐이라, TC-06이 반복돼 5세션 내내 갭이 NULL이면 **평균 없이 `personal`로 전환**된다. 그리고 F3-05는 P1·스코프 컷 7번이라 **자르면 P0인 F3-04와 TC-07이 같이 죽는다** — 카운트를 종료로 옮기면 잘라도 가드가 `fixed`를 안전하게 유지한다 |
| **데모 플래그 저장 위치 (2026-09-04 ⑥)** | **`profile.demo_mode` 컬럼.** 환경변수 목록 미채택 | `spec.md` §6-1·F11-01, `data-model.md`, `phase-1` | Phase 7이 환경변수를 택한 근거는 "컬럼은 마이그레이션이 한 번 더 필요"였는데, **Phase 1이 아직 `migration.sql`을 쓰는 중이라 성립하지 않는다.** 실제 차이는 심사 당일에 난다 — 환경변수는 재배포, 컬럼은 `UPDATE` 한 줄. `account`가 아니라 `profile`인 이유는 조회가 전부 `profileId` 기반이고 `account` 조인이 식별자 분리를 훼손하기 때문 |
| **로그 상관 수단 (2026-09-04 ⑥)** | **`sessionRef = SHA-256(sessionId)[:8]`.** `ops_error_log.message` 앞머리·앱 로그·`traceId`에 같은 값 | `data-model.md`, 절대 원칙 6번 | 발화도 `sessionId`도 못 남기면 `/internal/turns` 실패를 추적할 수단이 0이다. 해시는 인증에 쓸 수 없어 원칙 6번(CLM 인증 수단 노출 금지)을 깨지 않는다. 컬럼도 안 늘어난다 |

### 회신한 요청 (5건 전부 ✅)

회신은 백엔드가 `../../docs/response/{요청자}/`에 **요청과 같은 파일명**으로 썼다. 요청 본문은 고치지 않고 요청 문서의 상태 배너만 ✅로 바꿨다. 앞의 네 건은 계약서를 **v1.3 하나로 묶어**, 다섯째는 **v1.4**로 개정했다.

| 요청 | 회신 | 반영 |
| --- | --- | --- |
| [`hume-config-id.md`](../../docs/request/backend/hume-config-id.md) | [`response/app/hume-config-id.md`](../../docs/response/app/hume-config-id.md) | `humeConfigId` 필드 추가 (기동 시 fail-fast) |
| [`session-context-lookup.md`](../../docs/request/backend/session-context-lookup.md) | [`response/ai/session-context-lookup.md`](../../docs/response/ai/session-context-lookup.md) | §3-4 신설, CLM 인증 확정, `sessionId` UUID화 |
| [`live-turn-signal.md`](../../docs/request/backend/live-turn-signal.md) | [`response/app/live-turn-signal.md`](../../docs/response/app/live-turn-signal.md) | §2-13 신설(폴링), 재시도 3회 |
| [`session-summary-endpoint.md`](../../docs/request/backend/session-summary-endpoint.md) | [`response/ai/session-summary-endpoint.md`](../../docs/response/ai/session-summary-endpoint.md) | §3-5 신설(동기 3초) |
| [`tag-gap-endpoint.md`](../../docs/request/backend/tag-gap-endpoint.md) (2026-09-04) | [`response/app/tag-gap-endpoint.md`](../../docs/response/app/tag-gap-endpoint.md) | §2-8에 `tagGaps`·`userAvgGap` 추가 (v1.4) |

> **⚠️ 이 요청 하나를 놓칠 뻔했다.** `tag-gap-endpoint.md`는 이 폴더를 전면 재작성한 뒤에 도착했는데, 재작성본이 "4건 전부 회신 완료"라고 못박아둔 탓에 **다음에 이 파일을 읽을 때 새 요청을 찾을 이유가 사라져 있었다.** 앞으로 회신 현황을 볼 때는 이 표가 아니라 **`../../docs/request/backend/`의 실제 파일 목록**을 먼저 본다.

### 백엔드가 보낸 요청

`../../docs/response/backend/`로 회신이 들어온다. **2026-09-04 현재 회신 대기 2건.**

| 요청 | 대상 | 막고 있는 것 |
| --- | --- | --- |
| [`request/ai/integration-test-path.md`](../../docs/request/ai/integration-test-path.md) ⏳ | AI | 내부 API 4종의 **실제 통합 검증**. 양쪽 단위 개발은 안 막는다 |
| [`request/ai/turn-index-numbering.md`](../../docs/request/ai/turn-index-numbering.md) ⏳ (2026-09-04) | AI | 없음 — 계약 v1.4가 규칙을 정했고 확인만 남았다. **F2-07을 실제로 붙일 때 터진다** |

## 스펙 문서에서 발견한 불일치

구현 전에 알고 있어야 할, 문서 간 어긋난 지점을 적는다. **발견 즉시 이 표에 추가하고, 해소되면 "해소 (날짜)"로 표시를 바꾼다** (지우지 않는다 — 왜 헷갈렸는지가 기록이다).

| 지점 | 내용 | 처리 |
| --- | --- | --- |
| **백엔드 로컬 포트** | 앱 `.env.example`은 `API_BASE_URL=http://localhost:8080`, AI `.env.example`은 `BACKEND_BASE_URL=http://localhost:8000`. 두 역할이 다르게 가정 (2026-09-04 발견) | **해소 (2026-09-04)** — 해빙 설정 복제로 `server.port: ${PORT:8080}` 확정. **앱이 맞고 AI가 8080으로 고치면 된다.** `request/ai/integration-test-path.md`로 통보함 |
| **F9-02 담당** | spec 총괄표는 담당을 `C`(앱 단독)로 적었는데 계약 §2-8은 **서버가 `highlights`를 계산해 내려준다** (2026-09-04 ⑥ 발견) | **해소 (2026-09-04)** — spec 총괄표를 `A/C`로 정정. 계약이 맞고 총괄표가 틀렸다 |
| **Phase 문서의 응답 필드 나열** | 계약을 부분 복제하다 5곳이 어긋났다 — `evidence` 4키(실제 5키)·`total`·`feedback`·`expiresAt`·트렌드 3필드·대화 상세 상단 4필드 (2026-09-04 ⑥ 발견) | **해소 (2026-09-04)** — 나열을 전부 걷어내고 계약 §번호만 가리키게 했다. 결정 로그 "Phase 문서의 스키마 복제" 참조 |
| **`evidence` 키 개수** | 백엔드 문서 3곳이 "숫자 4개"라고 적었으나 계약 §2-6의 `evidence`는 **`tag`를 포함한 5키**다 (2026-09-04 ⑥ 발견) | **해소 (2026-09-04)** — `data-model.md`·`phase-4`·`phase-5` 정정 |
| `AI_TURN_POST_RETRIES` | AI `.env.example`이 아직 `1`이다. v1.3에서 **3회로 상향**했고 회신(`response/ai/session-context-lookup.md` 5번)에도 적었으나 AI 폴더 반영은 AI 몫 | 계약이 단일 출처이므로 문서상 불일치는 아니다. **`/internal/turns` 실패가 잦으면 이 값부터 확인**한다 |
| **`turnId`·`observationId`·`profileId` 형식** | 계약 §2-1·§2-2·§2-6·§2-7·§2-10 **예시**는 `prof_7f3a2b`·`turn_0031`·`obs_014`인데, `data-model.md`는 전 PK를 **UUID**로 정했다 (2026-09-04 발견, `profileId`는 ⑥에서 추가) | **계약 개정하지 않는다.** 계약이 형식을 규정한 필드는 `sessionId`(§1-1)뿐이고 나머지는 예시일 뿐이다. 이 ID들은 앱이 **그대로 되돌려주기만 하는 불투명 문자열**이라 형식이 바뀌어도 앱 코드가 깨지지 않는다. 다만 **예시만 보고 파싱하는 코드를 앱이 만들면 깨지므로**, 앱이 ID에서 의미를 추출하려 하면 그때 계약에 "불투명 문자열" 문구를 넣는다 |
