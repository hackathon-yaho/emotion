# Phase 1 — 골격 · 로컬 구동 · 인증

> 목표: **로컬에서 애플리케이션이 뜨고, DB에 붙어 있고, 카카오로 로그인해 JWT를 받는 상태**를 만든다. 감정 기능은 아직 하나도 없어도 된다.
>
> 근거: `roadmap.md` 착수 순서 1행 · `data-model.md` · `spec.md` F1 · `api-contract.md` §1·§2-1·§2-2·§2-12

> **상태 (2026-09-04): 코드 완료 · 테스트 18건 통과 · 로컬 기동 확인.**
> **2026-09-05 갱신** — 카카오 로그인을 **인가 코드 방식으로 교체**했다(계약 v1.6, 앱 회신). 실계정으로 `REST 키 인가 → 코드 교환 → JWT → /api/me` 왕복과 **TC-01**을 확인했고, `app_id` 대조 항목은 **필요 자체가 없어져** `redirectUri` 화이트리스트 검증으로 대체됐다.

> **배포는 이 Phase에서 하지 않는다** (2026-09-04 팀 결정). Render 등록·환경변수·cron 킵얼라이브는 **세 파트의 기능 확인이 끝난 뒤**에 한 번에 한다 — `roadmap.md`. 다만 `Dockerfile`은 지금 만들어 둔다(1-1). 배포 직전에 처음 빌드해 보면 그때 깨진다.

## 1-1. 프로젝트 생성

- [x] `backend/`에 Spring Boot 프로젝트 생성 — **Java 21 toolchain · Spring Boot 3.4.5 · Gradle Groovy(`build.gradle`)**
- [x] group `com.hackathonyaho`, 베이스 패키지 **`com.hackathonyaho.voicejournal`**
- [x] 의존성: `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-validation`, `postgresql`, Lombok
- [x] `Dockerfile` — `eclipse-temurin:21-jdk` 빌드 → `eclipse-temurin:21-jre` 실행, 멀티스테이지 (해빙 파일 복제)
- [x] `backend/.gitignore`에 `build/`, `.gradle/` 추가 — 루트 `.gitignore`가 이미 `.env*`를 막고 있어 시크릿은 커밋되지 않는다

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

- [x] `server.port: ${PORT:8080}` — **Render가 `PORT`를 주입**하므로 배포 시 자동으로 맞는다. 로컬 기본값 8080은 앱 `.env.example`과 일치한다
- [x] `spring.config.import: "optional:file:.env[.properties]"` — 로컬 `.env` 로딩
- [x] `spring.datasource.*`를 **환경변수로 주입.** 하드코딩 금지 — 로컬은 compose 값, 배포는 Supabase 값이 들어간다
- [x] `spring.jpa.hibernate.ddl-auto: none` — **JPA가 스키마를 만들지 않는다.** 스키마는 `db/migration.sql`이 단일 출처(`data-model.md`)

## 1-3. docker-compose (로컬 인프라)

- [x] `backend/docker-compose.yml` — Postgres 16 · `pgdata` 볼륨 · `pg_isready` 헬스체크 (해빙 파일 복제)
- [x] 애플리케이션이 컨테이너 DB에 붙는지 확인

> **로컬은 compose, 배포는 Supabase다.** 같은 PostgreSQL이라 `migration.sql`은 양쪽에 그대로 쓴다. 이렇게 나눈 이유는 **개발·테스트 쓰기가 도그푸딩 로그에 섞이지 않게** 하기 위함이다 — PRD §12 "발표 근거는 실사용 로그만". 한 DB를 같이 쓰면 F10-02 연쇄 무효화 때문에 나중에 골라내 지우는 것도 위험하다.

## 1-3-1. 시크릿 생성 (2026-09-04 확정)

셋 다 같은 방식으로 만든다. **다만 잃었을 때의 대가가 달라서 보관 등급을 나눈다.**

```sh
openssl rand -base64 32   # JWT_SECRET · TRANSCRIPT_ENC_KEY · INTERNAL_SHARED_SECRET 각각
```

| 시크릿 | 잃으면 | 보관 |
| --- | --- | --- |
| `JWT_SECRET` | 전원 재로그인. **재발급하면 끝** | Render 환경변수만 |
| `INTERNAL_SHARED_SECRET` | AI와 다시 나누면 끝. **재발급 가능** | Render 환경변수만 |
| **`TRANSCRIPT_ENC_KEY`** | **도그푸딩 발화 전체가 영구 복호화 불가** | Render 환경변수 **+ 저장소 밖 오프라인 사본 1부** |

- [x] 세 값을 만들어 로컬 `.env`에 넣는다 (`.gitignore` 대상인지 확인) — `TRANSCRIPT_ENC_KEY`·`INTERNAL_SHARED_SECRET`은 실값, Hume 키는 자리표시(AI 대기)
- [x] **로컬 개발용 키와 배포용 키를 분리한다** — DB가 이미 compose/Supabase로 나뉘어 있어 섞일 일이 없고, 로컬 키가 새도 도그푸딩 데이터는 안전하다
- [ ] **`TRANSCRIPT_ENC_KEY`(배포용)만** 저장소 밖에 사본을 남긴다 ← **배포 시점 (Phase 7)**

> **왜 이것만 특별한가** — 나머지 둘은 잃어도 새로 만들면 그만이지만, 이 키는 **그 키로 암호화된 데이터를 되살릴 방법이 없다.** F7-07(관찰 근거 열람)이 P0인데 통째로 죽고, §1.4의 "evidence 불일치 0건"을 증명할 수단이 사라진다. **DB 백업과 같은 급으로 다룬다.**

## 1-4. DB 스키마

- [x] `src/main/resources/db/migration.sql`에 [`data-model.md`](data-model.md)의 DDL을 **부모 테이블 먼저** 순서로 작성 (11테이블 + 인덱스)
- [x] **`profile.demo_mode`·`voice_session.gap_threshold`를 빠뜨리지 않는다** (2026-09-04 신설). 둘 다 뒤 Phase에서 쓰지만 **지금 넣어야 마이그레이션이 한 번으로 끝난다**
- [x] 로컬 compose Postgres에 적용
- [x] `gen_random_uuid()`가 동작하는지 확인 — **PostgreSQL 13+ 내장**이라 확장 설치가 필요 없다

> **Phase 1에서 11테이블을 전부 만든다.** Phase마다 쪼개 만들면 FK가 Phase를 가로지를 때(예: `crisis_event` → `voice_session`) 순서가 꼬인다. 테이블은 한 번에, 코드는 Phase별로.

## 1-5. 공통 오류 응답

- [x] `ErrorCode` enum에 계약 §1-2의 **10종**을 미리 정의 — `VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `KAKAO_VERIFY_FAILED`, `INTERNAL_AUTH_FAILED`, `FORBIDDEN`, `NOT_FOUND`, `SESSION_NOT_RESUMABLE`, `HUME_TOKEN_ISSUE_FAILED`, `INTERNAL_ERROR`
- [x] `GlobalExceptionHandler`로 응답 형태를 계약 §1-2 그대로 통일 — `{ "error": { "code", "message", "traceId" } }`
- [x] `message`는 **사용자에게 그대로 보여도 되는 한국어 문장**으로 쓴다(계약 §1-2). 앱이 code별 문구를 다시 만들지 않아도 되게
- [x] **`traceId`는 `sessionRef`와 같은 값을 쓴다** — 세션 컨텍스트가 있는 요청이면 `SHA-256(sessionId)[:8]`, 없으면 임의 8자(`data-model.md`)

> **`sessionId`를 로그에 못 남기므로**(절대 원칙 6번) `traceId`가 유일한 상관 수단이다. 해시를 쓰면 앱이 신고한 `traceId`로 `ops_error_log`와 애플리케이션 로그를 한 번에 찾을 수 있고, 값에서 세션을 역산할 수는 없다.

## 1-6. 카카오 로그인 · JWT (F1-01 · F1-02)

- [x] `POST /api/auth/kakao` — **응답은 계약 §2-1 그대로**
  - [x] **① `GET https://kapi.kakao.com/v1/user/access_token_info`** — 응답의 `app_id`가 **우리 앱 ID(`KAKAO_APP_ID` 환경변수)와 같은지 대조.** 다르면 401 `KAKAO_VERIFY_FAILED` — 아래 주의
  - [x] **② `GET https://kapi.kakao.com/v2/user/me`** — `id`(회원번호)를 얻어 `account.kakao_id`에 저장
  - [x] 신규면 `account` + `profile` + `account_profile` 생성 (한 트랜잭션)
  - [x] 자체 JWT 발급. **`expiresAt`은 JWT의 만료 시각과 같은 값**을 UTC ISO 8601로 내려준다 — 앱이 토큰을 파싱하지 않아도 되게
  - [x] 검증 실패 → 401 `KAKAO_VERIFY_FAILED` / 카카오 API 장애 → 503 `INTERNAL_ERROR`
- [x] JWT 인증 필터 — `Authorization: Bearer <JWT>`, **만료 7일**(계약 §1-1)
  - [x] `/api/auth/kakao`·`/api/health` 제외 **전 엔드포인트 필수**
  - [x] **`OPTIONS` 요청은 메서드 전체를 예외로 둔다** — CORS 프리플라이트에는 `Authorization`이 실리지 않아 401로 막힌다. 아래 1-6-1 참조
  - [x] 만료 시 401 `TOKEN_EXPIRED` — 앱이 카카오 재로그인으로 갱신한다
- [x] `GET /api/me` — **응답은 계약 §2-2 그대로**
  - [x] `sessionCount`는 `user_baseline.session_count`, `demoMode`는 `profile.demo_mode`, `thresholdMode`는 F3-04 규칙으로 그 자리에서 계산 (표시용이며 실제 적용 값은 세션 시작 시 다시 내려간다)
  - [x] **`openSession`은 Phase 2에서 채운다**(지금은 항상 `null`)

> **인가 코드 방식이다 (2026-09-05, 계약 v1.6).** 웹에서는 앱이 액세스 토큰을 받을 수 없어서다 — `kakao_flutter_sdk` 2.0.1의 웹 구현은 로그인 API가 전부 `notSupported`를 던지고 `authorize()`는 리다이렉트 후 빈 문자열을 돌려준다(앱이 소스로 확인). **종전의 `app_id` 대조는 걷어냈다** — 우리 REST 키로 교환한 토큰은 정의상 우리 앱 것이라 확인할 것이 없다.

> **⚠️ ①을 빼면 인가 코드를 남의 주소로 흘릴 수 있다.** `redirectUri`는 카카오에 그대로 전달되는 값이라, 검증 없이 받으면 공격자가 자기 주소로 인가를 받아 그 코드를 우리 서버로 교환시킬 수 있다. **정상 로그인만 해보면 안 잡히는 종류**라 완료 기준에도 넣었다.

> (참고) 이전 문단 — `/v2/user/me`는 "이 토큰이 어느 앱 것인지"를 묻지 않고 그냥 사용자 정보를 돌려준다. 카카오 앱은 누구나 만들 수 있으므로, 출처를 확인하지 않으면 **우리가 발급하지 않은 신원을 그대로 받아들이게 된다.** 호출 한 번이고, 빠뜨려도 정상 로그인은 멀쩡히 되기 때문에 **테스트로는 안 잡힌다** — 그래서 여기 적어둔다.

> **동의항목은 콘솔에서 전부 비활성이다 (2026-09-04 확정).** 닉네임·프로필 사진·이메일을 받지 않고 **회원번호만** 쓴다. `account` 테이블에 그 외를 담을 컬럼이 아예 없으므로 받아도 버리게 되고, PRD §5.1 "식별자 분리"와 F10-04 고지가 **콘솔 설정으로도 증명된다.** 덤으로 로그인 동의 화면이 가장 짧아져 첫 화면 이탈이 준다.

> **`KAKAO_REST_API_KEY`는 준비밀, `KAKAO_CLIENT_SECRET`은 진짜 비밀이다.** REST 키는 인가 URL에 실려 앱 번들에도 들어가지만(앱이 인가 URL을 만든다), **시크릿은 서버에만 남는다.** 코드 단독으로는 교환되지 않게 하는 것이 시크릿의 역할이다. `KAKAO_APP_ID`는 이제 쓰지 않는다.

> (참고) 앱 ID는 공개돼도 무해한 식별자라 저장소에 있어도 되지만, **콘솔에서 값을 바꾸거나 앱을 새로 만들 때 같이 바뀌므로** 환경변수로 둔다. Admin 키는 **서버에 두지 않는다** — 탈퇴 시 카카오 연결 해제는 앱이 사용자 토큰으로 한다(Phase 6).

> **카카오 회원번호는 앱마다 다르다.** 같은 사람이라도 다른 카카오 앱에서는 다른 번호를 받는다. 그래서 `kakao_id`는 **우리 앱 기준의 식별자**이고, ①의 대조가 그 전제를 지킨다.

> **감정 데이터 API는 `profileId`로만 동작한다.** 컨트롤러·서비스 어디에도 `kakao_id`가 흘러다니지 않게 한다 — 식별자 분리(PRD §5.1)는 테이블만 나눈다고 지켜지지 않고, 코드가 조인하면 무너진다.

## 1-6-1. CORS (앱이 다른 오리진에서 붙는다)

앱은 GitHub Pages에 배포돼 **백엔드와 오리진이 다르다.** 허용하지 않으면 브라우저가 모든 요청을 차단하고, **서버 로그에는 요청이 도달하지도 않는다.**

- [x] 허용 오리진을 **환경변수 목록**으로 — `CORS_ALLOWED_ORIGINS=https://hackathon-yaho.github.io,http://localhost:*`
- [x] **`allowedOriginPatterns`를 쓴다** (`allowedOrigins` 아님) — 와일드카드 포트를 받으려면 이쪽이어야 한다
- [x] 메서드 `GET`·`POST`·`DELETE`·`OPTIONS`, 헤더 `Authorization`·`Content-Type`
- [x] **`Allow-Credentials`는 켜지 않는다** — 앱이 쿠키를 쓰지 않고(JWT는 헤더), 켜면 와일드카드 오리진을 못 쓴다

> **오리진에 경로가 없다.** `https://hackathon-yaho.github.io/emotion/`이 아니라 **`https://hackathon-yaho.github.io`**다 — 브라우저가 보내는 `Origin` 헤더에는 경로가 없다. 앱이 "여기서 자주 어긋난다"고 짚어준 지점이다.

> **프리플라이트가 JWT 필터에 막히면 안 된다.** `OPTIONS`에는 `Authorization`이 실리지 않으므로, 필터를 "인증 제외 경로"로만 관리하면 401이 난다. **경로가 아니라 메서드로 예외를 둔다.** 이 실패는 앱에서 그냥 네트워크 오류로 보이고 서버에는 401만 남아 **원인이 CORS라는 걸 알아채는 데 한참 걸린다.**

> **환경변수인 이유** — 제품 이름이 정해지면 커스텀 도메인이 붙어 오리진이 한 번 더 바뀐다(PRD §14-6). 코드에 박으면 그때 재배포해야 한다. 근거는 `../../docs/response/app/cors-origin.md`.

## 1-7. 헬스체크 (F11-02)

- [x] `GET /api/health` — 인증 불필요, 계약 §2-12
  - [x] **DB 연결 확인을 포함**한다 (단순 `{"status":"ok"}` 반환이 아니다)
  - [x] 응답 `{ "status", "db", "timestamp" }`
- [x] 스케줄러 뼈대를 여기서 만든다 — **F2-06 미종료 세션 정리(Phase 2)와 F7-01 배치 스캔(Phase 4)이 같은 스케줄러에 올라탄다.** 추가 인프라 0
- [x] **주기는 5분** (`fixedDelay`, 2026-09-04 확정) — 아래 주의

> **5분으로 정한 이유** — F2-06이 "마지막 발화 후 30분 경과"를 판정하므로 실제 종료 시각의 오차가 최대 5분이다. `resumableUntil`이 그 시각과 같아서 이어하기 창도 그만큼만 밀린다. 배치도 대화 종료 후 5분 안에 돌아 "대화 끝내고 좀 있다 확인" 흐름과 맞는다. **1분은 빈 스캔이 60배로 늘고**(관찰은 3회·1.5배 조건이라 어차피 매번 안 생긴다), **10분은 이어하기 창이 40분까지 밀린다.**
>
> **`fixedRate`가 아니라 `fixedDelay`다** — 배치가 오래 걸릴 때 겹쳐 도는 것을 막는다. 인스턴스는 Render Free라 1개뿐이므로 분산 락은 필요 없다.
>
> **Render가 슬립하면 스케줄러도 멈춘다.** cron이 10분마다 `/api/health`를 쳐서 깨워두지만, 슬립 구간에 밀린 세션은 **깨어난 뒤 다음 주기에 주워간다** — `pattern_processed_at` 컬럼 방식이라 유실이 없다(F7-01).

> **이 엔드포인트가 나중에 두 가지를 동시에 막는다** — Render 15분 슬립(cron이 10분마다 호출)과 Supabase 유휴 일시정지. 그래서 DB에 실제로 닿아야 한다. 배포는 뒤로 미루지만 **엔드포인트는 지금 만든다.**

## 1-8. `DELETE /api/account` 라우트만 등록

- [x] 경로와 인증만 걸어두고 **실제 삭제 로직은 Phase 6**에서. 계약 §2-3

## 1-9. 테스트 기반 (2026-09-04 확정)

**통합 테스트까지 간다. 실DB는 이미 있는 compose Postgres를 재사용한다.**

- [x] `application-test.yml` — compose Postgres의 **테스트 전용 DB 이름**을 가리킨다(개발 데이터와 분리)
- [x] 테스트 시작 시 `db/migration.sql`을 적용한다 — **스키마도 같은 파일로 검증된다**
- [x] 각 테스트는 **트랜잭션 롤백**으로 격리한다
- [x] Phase마다 그 Phase의 것만 추가한다. Phase 1은 **인증·CORS·헬스체크**

> **Testcontainers를 쓰지 않는 이유** — 의존성과 첫 실행 이미지 풀이 붙는데, 그 값어치는 "외부 상태에 의존하지 않는다"에 있다. **백엔드에는 CI가 없어서**(GitHub Actions는 앱만 쓴다) 어차피 내 PC에서만 도는 테스트라 이득을 받을 곳이 없다. compose는 Phase 1이 이미 띄운다.
>
> **H2를 쓰지 않는 이유** — 스키마가 `gen_random_uuid()`·`jsonb`·부분 인덱스·`timestamptz`에 기대고 있다. **검증하려는 것이 정확히 그 부분**이라 H2에서는 통과하고 배포에서 깨진다.

> **다음 다섯은 틀려도 화면이 멀쩡해서 조용하다.** 각 Phase에서 반드시 테스트를 남긴다 — F7-03 규칙 판정(3회·1.5배) · F10-02 연쇄 무효화(3 미만 삭제/이상 재계산) · `/internal/turns` 중복 판별(`occurred_at` 비교) · F3-04 임계값 모드(`>=5 AND avg_gap NOT NULL`) · F3-05 baseline 재계산(NULL 갭 제외). 전부 순수 계산이라 DB 없이도 돈다.

## 완료 기준

- ✅ `docker compose up` 후 애플리케이션이 로컬에서 기동한다
- ✅ `GET /api/health`가 `{ "status": "ok", "db": "ok", ... }`를 반환한다
- ✅ **배포된 앱 오리진에서 `OPTIONS` 프리플라이트가 인증 없이 200/204로 통과한다** (브라우저 콘솔에 CORS 오류 0건)
- ✅ 11테이블이 로컬 DB에 만들어져 있다
- ✅ 카카오 로그인 → JWT 발급 → 그 JWT로 `GET /api/me` 호출이 통과한다 (2026-09-04 실계정 검증)
- ✅ **등록되지 않은 `redirectUri`를 보내면 400이다** (2026-09-05, 계약 v1.6으로 교체) — 종전의 `app_id` 대조 항목을 대신한다. 코드 교환 방식에서는 우리 REST 키로 교환한 토큰이 정의상 우리 앱 것이라 `app_id` 확인이 필요 없어졌다. **테스트로 못 박았다**
- ✅ **JWT 없이 감정 데이터 API를 호출하면 전부 401** (spec F1-02 수용 기준)
- ✅ **테스트가 compose DB에 붙어 돌고, `migration.sql`이 그대로 적용된다**
- ✅ **TC-01** — 재로그인 시 **동일 `profileId`** · `isNewUser: false` · 계정 행이 늘지 않음 (2026-09-04 실계정 검증. 같은 토큰 재사용 1회 + 리프레시로 받은 새 토큰 1회, 둘 다 동일)
- ✅ [`api-spec.md`](api-spec.md) 구현 현황 표에서 `/api/auth/kakao`·`/api/me`·`/api/health`를 `구현 완료`로 갱신했다

## 이 Phase에서 하지 않는 것

- **Render 배포·환경변수 등록·cron 킵얼라이브** — 세 파트 확인 후 (`roadmap.md`)
- 세션·턴·관찰 로직 (Phase 2~4)
- `DELETE /api/account`의 실제 삭제 (Phase 6)
- `GET /api/me`의 `openSession` 채우기 (Phase 2)
- **`demo_mode`를 켜는 일** — 컬럼은 지금 만들지만 값은 전부 `false`다. 심사 직전에 `UPDATE` 한 줄 (Phase 7)
- **로그아웃 서버 처리** — F1-03은 앱 로컬 저장소 정리이고 서버가 할 일이 없다(spec F1-03)
