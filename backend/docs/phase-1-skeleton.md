# Phase 1 — 골격 · 로컬 구동 · 인증

> 목표: **로컬에서 애플리케이션이 뜨고, DB에 붙어 있고, 카카오로 로그인해 JWT를 받는 상태**를 만든다. 감정 기능은 아직 하나도 없어도 된다.
>
> 근거: `roadmap.md` 착수 순서 1행 · `data-model.md` · `spec.md` F1 · `api-contract.md` §1·§2-1·§2-2·§2-12

> **배포는 이 Phase에서 하지 않는다** (2026-09-04 팀 결정). Render 등록·환경변수·cron 킵얼라이브는 **세 파트의 기능 확인이 끝난 뒤**에 한 번에 한다 — `roadmap.md`. 다만 `Dockerfile`은 지금 만들어 둔다(1-1). 배포 직전에 처음 빌드해 보면 그때 깨진다.

## 1-1. 프로젝트 생성

- [ ] `backend/`에 Spring Boot 프로젝트 생성 — **Java 21 toolchain · Spring Boot 3.4.5 · Gradle Groovy(`build.gradle`)**
- [ ] group `com.hackathonyaho`, 베이스 패키지 **`com.hackathonyaho.voicejournal`**
- [ ] 의존성: `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-validation`, `postgresql`, Lombok
- [ ] `Dockerfile` — `eclipse-temurin:21-jdk` 빌드 → `eclipse-temurin:21-jre` 실행, 멀티스테이지 (해빙 파일 복제)
- [ ] `backend/.gitignore`에 `build/`, `.gradle/` 추가 — 루트 `.gitignore`가 이미 `.env*`를 막고 있어 시크릿은 커밋되지 않는다

패키지 구조는 [README](README.md)의 "패키지 구조" 규칙을 따른다. **각 Phase에서 필요해질 때 만든다 — 빈 디렉터리를 미리 만들지 않는다.** Phase 1에서 생기는 것은 이것뿐이다.

```
com.hackathonyaho.voicejournal
├── VoiceJournalApplication.java
├── auth/       controller/ · dto/ · entity/ · repository/ · service/
├── health/     controller/ · service/
└── common/
    ├── enums/
    └── global/  ErrorCode.java
                 dto/ErrorResponse.java
                 exception/BusinessException.java
                 handler/GlobalExceptionHandler.java
```

## 1-2. `application.yml`

- [ ] `server.port: ${PORT:8080}` — **Render가 `PORT`를 주입**하므로 배포 시 자동으로 맞는다. 로컬 기본값 8080은 앱 `.env.example`과 일치한다
- [ ] `spring.config.import: "optional:file:.env[.properties]"` — 로컬 `.env` 로딩
- [ ] `spring.datasource.*`를 **환경변수로 주입.** 하드코딩 금지 — 로컬은 compose 값, 배포는 Supabase 값이 들어간다
- [ ] `spring.jpa.hibernate.ddl-auto: none` — **JPA가 스키마를 만들지 않는다.** 스키마는 `db/migration.sql`이 단일 출처(`data-model.md`)

## 1-3. docker-compose (로컬 인프라)

- [ ] `backend/docker-compose.yml` — Postgres 16 · `pgdata` 볼륨 · `pg_isready` 헬스체크 (해빙 파일 복제)
- [ ] 애플리케이션이 컨테이너 DB에 붙는지 확인

> **로컬은 compose, 배포는 Supabase다.** 같은 PostgreSQL이라 `migration.sql`은 양쪽에 그대로 쓴다. 이렇게 나눈 이유는 **개발·테스트 쓰기가 도그푸딩 로그에 섞이지 않게** 하기 위함이다 — PRD §12 "발표 근거는 실사용 로그만". 한 DB를 같이 쓰면 F10-02 연쇄 무효화 때문에 나중에 골라내 지우는 것도 위험하다.

## 1-4. DB 스키마

- [ ] `src/main/resources/db/migration.sql`에 [`data-model.md`](data-model.md)의 DDL을 **부모 테이블 먼저** 순서로 작성 (11테이블 + 인덱스)
- [ ] 로컬 compose Postgres에 적용
- [ ] `gen_random_uuid()`가 동작하는지 확인 — **PostgreSQL 13+ 내장**이라 확장 설치가 필요 없다

> **Phase 1에서 11테이블을 전부 만든다.** Phase마다 쪼개 만들면 FK가 Phase를 가로지를 때(예: `crisis_event` → `voice_session`) 순서가 꼬인다. 테이블은 한 번에, 코드는 Phase별로.

## 1-5. 공통 오류 응답

- [ ] `ErrorCode` enum에 계약 §1-2의 **10종**을 미리 정의 — `VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `KAKAO_VERIFY_FAILED`, `INTERNAL_AUTH_FAILED`, `FORBIDDEN`, `NOT_FOUND`, `SESSION_NOT_RESUMABLE`, `HUME_TOKEN_ISSUE_FAILED`, `INTERNAL_ERROR`
- [ ] `GlobalExceptionHandler`로 응답 형태를 계약 §1-2 그대로 통일 — `{ "error": { "code", "message", "traceId" } }`
- [ ] `message`는 **사용자에게 그대로 보여도 되는 한국어 문장**으로 쓴다(계약 §1-2). 앱이 code별 문구를 다시 만들지 않아도 되게

## 1-6. 카카오 로그인 · JWT (F1-01 · F1-02)

- [ ] `POST /api/auth/kakao` — 계약 §2-1
  - [ ] 앱이 보낸 카카오 액세스 토큰을 **카카오 API로 검증**
  - [ ] 신규면 `account` + `profile` + `account_profile` 생성 (한 트랜잭션)
  - [ ] 자체 JWT 발급 → `{ jwt, profileId, isNewUser }`
  - [ ] 검증 실패 → 401 `KAKAO_VERIFY_FAILED`
- [ ] JWT 인증 필터 — `Authorization: Bearer <JWT>`, **만료 7일**(계약 §1-1)
  - [ ] `/api/auth/kakao`·`/api/health` 제외 **전 엔드포인트 필수**
  - [ ] 만료 시 401 `TOKEN_EXPIRED` — 앱이 카카오 재로그인으로 갱신한다
- [ ] `GET /api/me` — 계약 §2-2. **`openSession`은 Phase 2에서 채운다**(지금은 항상 `null`)

> **감정 데이터 API는 `profileId`로만 동작한다.** 컨트롤러·서비스 어디에도 `kakao_sub`가 흘러다니지 않게 한다 — 식별자 분리(PRD §5.1)는 테이블만 나눈다고 지켜지지 않고, 코드가 조인하면 무너진다.

## 1-7. 헬스체크 (F11-02)

- [ ] `GET /api/health` — 인증 불필요, 계약 §2-12
  - [ ] **DB 연결 확인을 포함**한다 (단순 `{"status":"ok"}` 반환이 아니다)
  - [ ] 응답 `{ "status", "db", "timestamp" }`
- [ ] 스케줄러 뼈대를 여기서 만든다 — **F2-06 미종료 세션 정리(Phase 2)와 F7-01 배치 스캔(Phase 4)이 같은 스케줄러에 올라탄다.** 추가 인프라 0

> **이 엔드포인트가 나중에 두 가지를 동시에 막는다** — Render 15분 슬립(cron이 10분마다 호출)과 Supabase 유휴 일시정지. 그래서 DB에 실제로 닿아야 한다. 배포는 뒤로 미루지만 **엔드포인트는 지금 만든다.**

## 1-8. `DELETE /api/account` 라우트만 등록

- [ ] 경로와 인증만 걸어두고 **실제 삭제 로직은 Phase 6**에서. 계약 §2-3

## 완료 기준

- `docker compose up` 후 애플리케이션이 로컬에서 기동한다
- `GET /api/health`가 `{ "status": "ok", "db": "ok", ... }`를 반환한다
- 11테이블이 로컬 DB에 만들어져 있다
- 카카오 로그인 → JWT 발급 → 그 JWT로 `GET /api/me` 호출이 통과한다
- **JWT 없이 감정 데이터 API를 호출하면 전부 401** (spec F1-02 수용 기준)
- **TC-01** — 로그인 → 로그아웃 → 재로그인 시 **동일 `profileId`**가 나오고 이전 데이터가 그대로 조회된다
- [`api-spec.md`](api-spec.md) 구현 현황 표에서 `/api/auth/kakao`·`/api/me`·`/api/health`를 `구현 완료`로 갱신했다

## 이 Phase에서 하지 않는 것

- **Render 배포·환경변수 등록·cron 킵얼라이브** — 세 파트 확인 후 (`roadmap.md`)
- 세션·턴·관찰 로직 (Phase 2~4)
- `DELETE /api/account`의 실제 삭제 (Phase 6)
- `GET /api/me`의 `openSession` 채우기 (Phase 2)
- **로그아웃 서버 처리** — F1-03은 앱 로컬 저장소 정리이고 서버가 할 일이 없다(spec F1-03)
