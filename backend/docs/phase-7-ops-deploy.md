# Phase 7 — 운영 · 배포

> 목표: **심사장에서 갭이 보이고, 장애가 나면 원인을 알 수 있고, 팀이 링크로 접속할 수 있는 상태**를 만든다.
>
> 의존: 데모 모드는 Phase 1(`profile.demo_mode` 컬럼)·Phase 2(플래그 전달)·Phase 3(`/live` 분기)가 있어야 의미가 생긴다. 오류 로깅은 Phase 1부터 병행 가능.
>
> 근거: `spec.md` F11-01·F11-03·F11-04 · PRD FR-090·FR-092 · `roadmap.md`

> **배포는 세 파트(앱·백엔드·AI)의 기능 확인이 끝난 뒤에 한다**(2026-09-04 팀 결정, PRD §12). 도그푸딩이 웹 링크 공유로 진행되므로 **배포 시점이 곧 도그푸딩 시작 시점**이다. 그 전의 역할 간 통합 검증은 배포가 아니라 **임시 터널**로 한다 — `../../docs/request/ai/integration-test-path.md`.

## 7-1. 데모 모드 (F11-01)

**여기서 만들 것은 없다.** 플래그(`profile.demo_mode`)는 Phase 1의 스키마에 있고, 전달은 Phase 2(`session/start`·`/internal/sessions`), 분기는 Phase 3(`/live`)에 이미 있다.

- [ ] 데모로 쓸 계정으로 로그인해 `profileId`를 확인
- [ ] `UPDATE profile SET demo_mode = true WHERE id = ?` — **재배포 없음**
- [ ] `POST /api/session/start` 응답의 `demoMode`가 `true`로 오는지, `/live`의 `turns`가 채워지는지 확인
- [ ] 시연이 끝나면 되돌린다

> **컬럼으로 정한 이유** (2026-09-04 변경) — 종전 안은 환경변수에 profile ID를 나열하는 것이었고, 근거는 "컬럼을 추가하면 마이그레이션이 한 번 더 필요하다"였다. **Phase 1이 아직 `migration.sql`을 쓰는 중이라 그 전제가 성립하지 않는다.** 실제 차이는 심사 당일에 난다 — 환경변수는 값을 바꾸는 데 Render 재배포(슬립 + 빌드 대기)가 필요하고, 컬럼은 `UPDATE` 한 줄이다.
> **일반 사용자 화면에는 노출되지 않는다**(TC-14). 서버가 `turns: []`로 막으므로 앱이 실수해도 그릴 데이터가 없다.

## 7-2. 오류 로깅 (F11-03)

- [ ] 구조화 로그 + `ops_error_log` 적재
- [ ] **발화 내용(`transcript`)을 남기지 않는다** — FR-092, 백엔드 절대 원칙 3번
- [ ] **`sessionId`를 남기지 않는다** — CLM 인증 수단이라 비밀과 동급(절대 원칙 6번)
- [ ] **`sessionRef`(해시 8자)는 남긴다** — 이게 없으면 장애를 추적할 수단이 0이다(`data-model.md`). 감사 시 grep 대상은 **UUID 패턴**이고 8자 해시는 통과다
- [ ] `crisis_event`에도 발화 내용이 없는지 재확인 (Phase 3에서 만들었지만 여기서 감사한다)

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
- [ ] `Dockerfile`로 빌드 (Phase 1에서 이미 만들어 뒀다)
- [ ] 환경변수 등록 — `SPRING_DATASOURCE_*`(Supabase) · `HUME_API_KEY` · `HUME_CONFIG_ID` · `INTERNAL_SHARED_SECRET` · `TRANSCRIPT_ENC_KEY` · `JWT_SECRET` · 카카오 앱 시크릿 · **`CORS_ALLOWED_ORIGINS`**
- [ ] **`HUME_API_KEY`·`HUME_CONFIG_ID`는 AI에게서 받는다** — 계정을 AI가 소유한다(2026-09-04 결정, `roadmap.md`)
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

> **환경변수를 코드에 하드코딩하지 않는다.** 특히 `TRANSCRIPT_ENC_KEY`·`INTERNAL_SHARED_SECRET`은 저장소에 절대 넣지 않는다.

## 완료 기준

- **TC-14** — 데모 모드 on/off로 S02 갭 노출이 갈린다
- **TC-20** — 평가 세트 실행으로 전 지표가 1회 출력된다 (P1)
- **로그 전수 검사에서 `transcript` 0건, `sessionId` 0건**
- 배포된 URL로 앱이 로그인·대화 시작까지 완주한다
- cron 등록 후 첫 요청이 즉시 응답한다 (슬립 없음)
- `api-spec.md`의 구현 현황이 **전부 `구현 완료`**다

## 이 Phase에서 하지 않는 것

- **AI서버 배포** — AI 담당이 각자 계정에서
- **앱 배포** — 앱 담당
- 모니터링·알림 도구 도입 — `ops_error_log`와 Render 로그로 충분하다
- 스케일링·부하 테스트 — 도그푸딩 3인 규모에 필요 없다
