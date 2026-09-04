# Phase 7 — 운영 · 배포

> 목표: **심사장에서 갭이 보이고, 장애가 나면 원인을 알 수 있고, 팀이 링크로 접속할 수 있는 상태**를 만든다.
>
> 의존: 데모 모드는 Phase 1(`profile.demo_mode` 컬럼)·Phase 2(플래그 전달)·Phase 3(`/live` 분기)가 있어야 의미가 생긴다. 오류 로깅은 Phase 1부터 병행 가능.
>
> 근거: `spec.md` F11-01·F11-03·F11-04 · PRD FR-090·FR-092 · `roadmap.md`

> **상태 (2026-09-05): 배포 전 준비는 끝났다. 남은 것은 계정 두 개(Supabase·Render)를 만드는 일뿐이다.**
> **배포 이미지로 실제 확인한 것** — Docker 빌드 성공 · `PORT` 주입으로 기동(10000) · DB 연결 · **TC-14 데모 모드 전환** · 로그 감사. 아래 7-1·7-2는 닫혔고 7-4만 남았다.

> **배포는 세 파트(앱·백엔드·AI)의 기능 확인이 끝난 뒤에 한다**(2026-09-04 팀 결정, PRD §12). 도그푸딩이 웹 링크 공유로 진행되므로 **배포 시점이 곧 도그푸딩 시작 시점**이다. 그 전의 역할 간 통합 검증은 배포가 아니라 **임시 터널**로 한다 — `../../docs/request/ai/integration-test-path.md`.

## 7-1. 데모 모드 (F11-01)

**여기서 만들 것은 없다.** 플래그(`profile.demo_mode`)는 Phase 1의 스키마에 있고, 전달은 Phase 2(`session/start`·`/internal/sessions`), 분기는 Phase 3(`/live`)에 이미 있다.

- [x] 데모로 쓸 계정으로 로그인해 `profileId`를 확인
- [x] `UPDATE profile SET demo_mode = true WHERE id = ?` — **재배포 없음**
- [x] `/live`의 `turns`가 채워지는지 확인 — **배포 이미지(Docker + `PORT` 주입)에서 확인했다** (2026-09-05)
  - `demo_mode = false` → `turns: []`, `demo_mode = true` → `turns` 채워짐. `GET /api/me`의 `demoMode`도 함께 뒤집힌다
  - ⏳ `POST /api/session/start` 응답의 `demoMode`는 **Hume 키가 있어야** 그 응답 자체가 나온다. 같은 코드가 읽는 값이라 위험은 없다
- [x] 시연이 끝나면 되돌린다 — 확인 후 `false`로 원복했다

> **컬럼으로 정한 이유** (2026-09-04 변경) — 종전 안은 환경변수에 profile ID를 나열하는 것이었고, 근거는 "컬럼을 추가하면 마이그레이션이 한 번 더 필요하다"였다. **Phase 1이 아직 `migration.sql`을 쓰는 중이라 그 전제가 성립하지 않는다.** 실제 차이는 심사 당일에 난다 — 환경변수는 값을 바꾸는 데 Render 재배포(슬립 + 빌드 대기)가 필요하고, 컬럼은 `UPDATE` 한 줄이다.
> **일반 사용자 화면에는 노출되지 않는다**(TC-14). 서버가 `turns: []`로 막으므로 앱이 실수해도 그릴 데이터가 없다.

## 7-2. 오류 로깅 (F11-03)

- [x] 구조화 로그 + `ops_error_log` 적재
- [x] **발화 내용(`transcript`)을 남기지 않는다** — 코드 전수 grep **0건**
- [x] **`sessionId`를 남기지 않는다** — 코드 전수 grep **0건**. **실행 로그 전수에서도 UUID 0건** (2026-09-05)
- [x] **`sessionRef`(해시 8자)는 남긴다** — `ops_error_log` 적재 지점 2곳(`TURN_INDEX_COLLISION`·`PATTERN_BATCH_FAILED`) 모두 `sessionRef`만 쓴다
- [x] `crisis_event`에도 발화 내용이 없는지 재확인 — 컬럼이 `profile_id`·`session_id`·`detected_by`뿐이고 `turn_id`가 없다
- [x] **음성 파일을 쓰는 코드가 없는지** — `.wav`·`.mp3`·`audio/`·`MultipartFile` grep **0건** (TC-11)

> **감사 결과 (2026-09-05)** — 실행 로그에서 UUID가 나온 파일은 **전부 AI서버와 테스트 도구**였고 백엔드 로그는 0건이다. AI 쪽은 별건으로 요청했다(`../../docs/request/ai/integration-round-1.md`).

> **이 항목은 Phase 1부터 지켜야 하고, 여기서 감사한다.** 나중에 넣는 기능이 아니라 처음부터 안 넣는 규칙이다. Phase 7에 있는 이유는 **전 구간을 훑어 검사**하기 때문이다.
>
> 검사 방법: 로그 전수에서 `transcript` 문자열과 UUID 패턴을 grep한다. 도그푸딩 로그로 검사하면 실제 발화가 걸리므로 **개발 중 로컬 로그로 먼저** 한다.

## 7-3. 평가 세트 실행 (F11-04, **P1**)

- [ ] 20쌍 고정 세트를 돌려 §1.4 지표 산출 — 갭 방향 일치율 / 재현성 편차 / 위기 재현율 / evidence 불일치 건수 / 원문 외 태그 건수
- [ ] **세트 자체와 대부분의 지표는 AI서버 소관**이다. 백엔드는 evidence 불일치 검사처럼 **DB를 훑어야 하는 것**만 맡는다

> **P1이라 잘려도 된다**(spec §11 스코프 컷 8번) — 수동 실행으로 대체한다.
> **한계를 결과와 함께 표기한다**: 팀원 3인 음성이라 일반화 근거가 아니다(PRD §2.5).

## 7-4. 배포 (Render)

**세 파트 기능 확인이 끝난 뒤 착수한다.**

- [ ] Render Web Service 생성 — **AI서버와 별도 계정**(무료 750시간은 워크스페이스당)
- [x] `Dockerfile`로 빌드 — **2026-09-05에 실제로 빌드해 컨테이너를 띄웠다**
  - ⚠️ **`gradlew`에 실행 비트가 없었다**(git `100644`). 리눅스에서 `./gradlew`가 permission denied로 죽는다 — **배포 당일에야 드러났을 결함**이다. `git update-index --chmod=+x`로 올리고 `Dockerfile`에도 `chmod +x`를 넣었다(Windows에서 다시 추가되면 또 사라지므로 두 겹)
  - `PORT=10000`을 주입해 기동·DB 연결·헬스체크·TC-14까지 확인했다
- [ ] 환경변수 등록 — **아래 표가 단일 출처다.** 코드(`application.yml`)에서 뽑았다

| 변수 | 필수 | 어디서 오나 |
| --- | --- | --- |
| `SPRING_DATASOURCE_URL` | **필수** | Supabase Connection string (**Session pooler 5432**) |
| `SPRING_DATASOURCE_USERNAME` | **필수** | 〃 |
| `SPRING_DATASOURCE_PASSWORD` | **필수** | 〃 |
| `JWT_SECRET` | **필수** | `openssl rand -base64 32` — 배포용을 새로 만든다 |
| `TRANSCRIPT_ENC_KEY` | **필수** | 〃. **잃으면 발화 전체가 복호화 불가** — 저장소 밖 사본 1부 |
| `INTERNAL_SHARED_SECRET` | **필수** | 이미 생성해 AI와 공유했다(로컬용). **배포용을 새로 만들고 AI에 다시 준다** |
| `KAKAO_REST_API_KEY` | **필수** | 카카오 콘솔 (계약 v1.6 — 종전 `KAKAO_APP_ID`는 **더 이상 쓰지 않는다**) |
| `HUME_API_KEY` | **필수** | AI (계정 소유) |
| `HUME_SECRET_KEY` | **필수** | 〃 |
| `HUME_CONFIG_ID` | **필수** | 〃 |
| `KAKAO_CLIENT_SECRET` | 선택 | 카카오가 REST 키에 기본 활성화로 붙여 준다. 비면 안 보낸다 |
| `KAKAO_REDIRECT_URIS` | 선택 | 기본값이 콘솔 등록값과 같다. 커스텀 도메인이 붙으면 추가 |
| `CORS_ALLOWED_ORIGINS` | 선택 | 기본값에 GitHub Pages가 이미 있다 |
| `AI_SERVER_BASE_URL` | 선택 | **AI서버 배포 주소.** 기본값은 로컬(8100)이라 **배포에서는 반드시 넣어야** 요약·관찰이 돈다 |
| `GAP_THRESHOLD` | 선택 | 20쌍 측정 후 확정(PRD §14-5). 그때까지 기본값 |
| `PORT` | 선택 | **Render가 자동 주입한다.** 우리가 넣지 않는다 |

> **필수 8개 중 하나라도 없으면 서버가 기동하지 않는다.** 런타임 오류가 아니라 부팅 실패라, 배포 로그 첫 화면에서 바로 보인다 — 의도한 설계다(`SessionPolicy`).
>
> **문서의 종전 목록에 `KAKAO_APP_ID`가 있었다** (2026-09-05 정정). 계약 v1.6에서 인가 코드 방식으로 바뀌며 없어진 변수인데 목록에 남아 있었고, **대신 필수인 `KAKAO_REST_API_KEY`가 빠져 있었다.** 그대로 등록했으면 배포가 부팅에서 죽었다.
- [x] **카카오 Admin 키는 등록하지 않는다** — 탈퇴 unlink는 **백엔드가 사용자 토큰으로** 한다(2026-09-05 개정, Phase 6). Admin 키는 여전히 쓰지 않는다
- [ ] **`HUME_API_KEY`·`HUME_CONFIG_ID`는 AI에게서 받는다** — 계정을 AI가 소유한다(2026-09-04 결정, `roadmap.md`)
- [ ] **Supabase 프로젝트를 이 시점에 만든다** — 미리 만들면 무료 플랜이 1주 미사용에 일시정지돼 깨우는 절차만 는다. 로컬은 compose로 충분했다
- [ ] **연결은 Session pooler(5432)를 쓴다** — 아래
- [ ] `db/migration.sql`을 **Supabase에 적용** (로컬과 같은 파일)
- [ ] cron-job.org에 **10분 간격** `GET /api/health` 등록
- [ ] 앱·AI에 배포 도메인 전달

| 확인 | 이유 |
| --- | --- |
| `PORT` 주입으로 뜨는지 | Render가 포트를 지정한다. `${PORT:8080}`이 이걸 받는다 |
| 첫 요청이 1분 걸리는지 | 슬립 상태면 복귀에 약 1분. cron이 돌기 시작하면 사라진다 |
| **`TRANSCRIPT_ENC_KEY`를 별도 보관했는지** | **잃으면 도그푸딩 발화 전체가 복호화 불가** (Phase 3) |
| 750시간 잔량 | 24시간 킵얼라이브면 30일에 약 720시간. **다른 무료 서비스를 같은 계정에 두면 둘 다 정지된다** |
| **배포 오리진에서 CORS가 통과하는지** | 앱은 `https://hackathon-yaho.github.io`에 있다. **커스텀 도메인이 붙으면 `CORS_ALLOWED_ORIGINS`에 추가**하면 되고 재배포는 필요 없다 |

> **Session pooler를 쓰는 이유** — Render에서 Supabase로 직접 연결하면 IPv6 경로 문제를 만난다. **Transaction pooler(6543)는 prepared statement를 지원하지 않아** JPA·HikariCP와 부딪히므로, **Session pooler(5432)**가 우리 조합에서 맞는 선택이다. 연결 문자열은 Supabase 콘솔의 Connection string에서 그대로 복사한다.

> **`ops_error_log`는 관리자 API를 만들지 않는다** (2026-09-04 확정). **Supabase 대시보드에서 SQL로 본다.** 3인 규모에 화면 하나를 만들 값어치가 없고, 만들면 그 API 자체가 인증·권한 설계 대상이 된다 — 발화를 안 담는 테이블이라도 조회 경로가 생기면 그렇다.

> **환경변수를 코드에 하드코딩하지 않는다.** 특히 `TRANSCRIPT_ENC_KEY`·`INTERNAL_SHARED_SECRET`은 저장소에 절대 넣지 않는다.

## 완료 기준

- ✅ **TC-14** — 데모 모드 on/off로 갭 노출이 갈린다 — **배포 이미지에서 확인**(`UPDATE` 한 줄, 재배포 없음). S02 화면 확인은 앱 몫
- ⏳ **TC-20** — 평가 세트 실행으로 전 지표가 1회 출력된다 (P1) — 세트는 AI 소관이고 키가 있어야 돈다
- ✅ **로그 전수 검사에서 `transcript` 0건, `sessionId` 0건** — 코드·실행 로그 양쪽
- ⏳ 배포된 URL로 앱이 로그인·대화 시작까지 완주한다 — 배포 후
- ⏳ cron 등록 후 첫 요청이 즉시 응답한다 (슬립 없음) — 배포 후
- ✅ `api-spec.md`의 구현 현황이 **전부 `구현 완료`**다

## 배포 당일 순서 (계정 두 개만 만들면 된다)

**앞의 준비는 끝났다.** 이 순서대로 하면 된다.

1. **Supabase 프로젝트 생성** → Connection string에서 **Session pooler(5432)** 문자열을 복사
2. Supabase SQL Editor에 **`src/main/resources/db/migration.sql`을 그대로 붙여넣기** — 로컬과 같은 파일이다
3. **배포용 시크릿 3개를 새로 생성** — `JWT_SECRET` · `TRANSCRIPT_ENC_KEY` · `INTERNAL_SHARED_SECRET`
   ```sh
   openssl rand -base64 32
   ```
   - **`TRANSCRIPT_ENC_KEY`는 저장소 밖에 사본 1부.** 잃으면 도그푸딩 발화 전체가 복호화 불가다
   - **`INTERNAL_SHARED_SECRET`은 AI에게 다시 준다** — 로컬용과 다른 값이다
4. **Render Web Service 생성** — 저장소 연결, 루트 디렉터리 `backend`, Dockerfile 빌드
5. **환경변수 등록** — 위 표의 **필수 8개**. `PORT`는 넣지 않는다(Render가 준다)
6. 첫 배포 → **로그 첫 화면에서 부팅 성공 확인.** 필수 변수가 빠졌으면 여기서 죽는다
7. `GET /api/health`가 `{"status":"ok","db":"ok"}`인지 확인
8. **cron-job.org에 10분 간격 `GET /api/health` 등록**
9. **앱·AI에 배포 도메인 전달** — 앱은 `API_BASE_URL`, AI는 `BACKEND_BASE_URL`
   - 앱 것은 **팀장이 직접 등록한다**: `gh variable set API_BASE_URL --repo hackathon-yaho/emotion --body https://…` (`.github/workflows/app-web.yml`이 `vars.API_BASE_URL`을 읽고, **비어 있으면 폴백이 `http://localhost:8080`이라 배포본이 조용히 로컬을 부른다**). `KAKAO_REST_KEY`는 2026-09-05에 등록해 뒀다
10. AI서버가 배포되면 **`AI_SERVER_BASE_URL`을 그 주소로** 갱신

> **10번을 빠뜨리면 조용히 실패한다.** 요약은 `null`, 관찰은 0건이 되는데 **둘 다 정상 동작과 구분이 안 된다**(설계상 실패해도 대화·기록은 멀쩡하다). 배포 후 첫 대화에서 `summary`가 `null`이면 이걸 먼저 본다.

## 이 Phase에서 하지 않는 것

- **AI서버 배포** — AI 담당이 각자 계정에서
- **앱 배포** — 앱 담당
- 모니터링·알림 도구 도입 — `ops_error_log`와 Render 로그로 충분하다
- 스케일링·부하 테스트 — 도그푸딩 3인 규모에 필요 없다
