# 백엔드 작업 문서

> **수정 기록 (2026-09-05 ⑰)** — **Phase 5 구현 완료.** 조회 6개 — 관찰 목록·근거·피드백 · 트렌드 · 대화 기록 목록·상세. **테스트 73건 통과.** **구현하다 결함 하나를 잡았다** — `range`를 생략하면 `GET /api/trend`가 **500**이었다. `Map.of()`가 `containsKey(null)`에서 예외를 던지는데 **`range` 생략이 가장 흔한 호출**이라, 기본 경로가 통째로 죽는 자리였다. 테스트를 `range=7d`로만 짰으면 못 잡았다. 계약에 규정이 없던 것 둘을 정했다 — ① **기록 목록은 끝난 세션만** 내려간다(진행 중인 대화가 목록에 뜨면 "지난 대화"로 읽힌다. 이어하기 제안은 `openSession`이 맡는다) ② **`highlights` 구간은 기록이 없는 날에서 끊는다**(이어 붙이면 대화가 없던 날까지 "갭이 높았던 기간"으로 칠하게 된다). 값의 단일 출처를 지킨 것 — **`userAvgGap`은 세 곳(baseline·관찰 evidence·트렌드)이 전부 `user_baseline.avg_gap` 하나를 읽는다.** 조회 시점에 다시 계산하면 §1.4 "evidence 불일치 0건"이 그 순간 깨진다. **`highlights`가 세션 스냅샷으로 판정하는 것**은 같은 데이터에서 스냅샷만 올리자 구간이 사라지는 것으로 확인했다.
>
> **수정 기록 (2026-09-05 ⑯)** — **Phase 4 구현 완료.** 패턴 배치가 스케줄러에 올라갔다 — 태그별 집계(전체 기간·갭 NULL 제외) → **코드 판정**(3회 이상 AND 1.5배 이상) → 통과한 것만 문장화 요청 → `observation` + `observation_evidence`. **테스트 59건 통과.** **`/internal/sessions`의 `recentObservations`가 실제 값이 됐다**(실서버 확인). **AI서버가 없어 지금은 관찰이 0건이고 그게 설계대로다** — 템플릿 폴백을 두지 않으므로 문장화가 실패하면 관찰을 만들지 않고 다음 주기에 다시 시도한다. 테스트로 못 박은 것 — 2회만 등장하면 갭이 아무리 커도 침묵(TC-16) · 3회를 넘겨도 1.5배 미만이면 침묵 · `avg_gap`이 NULL이면 판정 자체를 안 함 · **갭 NULL 턴은 등장 횟수에서도 빠짐** · 문장화 실패 시 관찰 0건 · evidence 건수 = `occurrences`(TC-17) · 종료 안 된 세션은 대상 아님 · 처리된 세션은 다시 안 돎. **spec에 규정이 없던 것 하나를 정했다** — **같은 태그로 이미 살아 있는 관찰이 있으면 새로 만들지 않는다.** 집계가 전체 기간이라 한 번 조건을 넘긴 태그는 세션마다 계속 넘기고, 그대로 두면 **발견 화면이 같은 문장으로 도배되고 AI 호출도 매번 나간다.** 관찰을 "시점의 발견"으로 두고 숫자가 자라도 갱신하지 않는다 — **더 강한 패턴으로 갱신할지는 도그푸딩 뒤에 정한다.** **알려진 한계 1건**: AI 호출이 트랜잭션 안에서 일어나 태그마다 최대 10초 커넥션을 쥔다. 인스턴스 1개·3인 규모에서는 문제없지만 사용자가 늘면 트랜잭션 밖으로 빼야 한다.
>
> **수정 기록 (2026-09-05 ⑮)** — **Phase 3 구현 완료.** 턴 적재(`POST /internal/turns`) · **발화 AES-GCM 암호화**(JPA 변환기) · 태그·위기 저장 · **중복 적재 판별** · `GET /api/session/{id}/live` · **`POST /internal/summaries` 호출**(Phase 2에서 미룬 것) · F3-05 baseline 재계산. **테스트 50건 통과.** **AI서버의 고정 픽스처 3종(`ai-server/eval/fixtures/internal/`)을 그대로 `curl`로 보내 실서버에서 확인**했다 — 202 · 저장 · 암호화 · assistant/분석실패 턴의 null 처리까지. **재시도와 충돌도 실서버에서 갈렸다**: 같은 페이로드 두 번 → 행 1개, 같은 인덱스 + 다른 `occurredAt` → 행 2개 + `sessionRef=a3a9e1ed requested=40 stored=60`(발화·sessionId 없음). **적재 p95 20ms**(목표 200ms). 구현 중 결정·발견 4건 — ① **중복 판별을 "위반 잡기"가 아니라 "먼저 조회"로 했다.** 제약 위반은 트랜잭션을 롤백 전용으로 만들어 같은 트랜잭션에서 재번호 저장을 이어갈 수 없다. 경합은 `unique`가 여전히 막고 그때는 5xx → AI 재시도 → 이 경로에서 걸린다 ② **깨진 JSON이 500이었다 → 400으로 고쳤다.** 계약 §3-2에서 AI는 5xx를 3회 재시도하는데, 본문이 깨진 요청은 재시도해도 같은 결과다. **파서 예외 메시지는 로그에 넣지 않는다** — 본문 조각이 곧 발화다(Jackson이 기본으로 가리지만 설정 하나에 달린 방어를 믿지 않는다) ③ **`ops_error_log`는 `REQUIRES_NEW`로 쓴다** — 오류를 남기는 쪽은 대개 롤백되는 경로라, 같은 트랜잭션에 실으면 기록도 함께 사라진다 ④ **`turn_tag`·`crisis_event`·`ops_error_log`는 엔티티 없이 `JdbcTemplate`으로 쓴다** — Phase 3은 쓰기만 하고 Phase 4의 집계는 `group by` SQL이라 엔티티를 거치지 않는다. **로그 위생 실측**: 발화 0건 · `sessionId` 0건 · 태그 0건.
>
> **수정 기록 (2026-09-05 ⑭)** — **카카오 로그인을 인가 코드 방식으로 교체했다 (계약 v1.6).** 앱 회신(`response/backend/kakao-web-login.md`)이 SDK 2.0.1 소스로 확인해 왔다 — **웹 빌드에서는 로그인 API가 전부 `notSupported`를 던지고 `authorize()`는 리다이렉트 후 빈 문자열을 돌려준다.** 즉 액세스 토큰 방식은 웹에서 성립하지 않는다. ① **§2-1 요청을 `kakaoAccessToken` → `kakaoAuthCode` + `redirectUri`로 교체**하고 서버가 REST 키 + 시크릿으로 교환한다 ② **`redirectUri`를 등록 목록과 대조**한다 — 카카오에 그대로 전달되는 값이라 열어두면 공격자가 자기 주소로 인가받은 코드를 우리 서버로 교환시킬 수 있다. **카카오를 부르기 전에 400으로 막고** 테스트로 못 박았다 ③ **`app_id` 대조를 걷어냈다** — 우리 REST 키로 교환한 토큰은 정의상 우리 앱 것이라 확인할 것이 없어졌다. Phase 1의 유일한 ⏳였는데 **항목 자체가 사라졌다** ④ **탈퇴 unlink 담당이 앱 → 백엔드로 넘어왔다** — 인가 코드 방식에서는 앱에 카카오 자격증명이 남지 않는다. **Admin 키도 리프레시 토큰도 쓰지 않는다**: unlink는 사용자 액세스 토큰으로 동작하고, 토큰을 보관하면 전 사용자의 2개월짜리 카카오 자격증명을 우리 DB가 들고 있게 돼 "저장하는 것은 회원번호 하나"라는 주장과 어긋난다. **탈퇴 시점에 앱이 인가를 한 번 더 통과해 코드를 넘긴다**(§2-3 선택 본문). 앱에 요청 1건 — `request/app/kakao-rest-key-switch.md`(⏳): 인가 URL의 `client_id`를 REST 키로 쓰면 혼용 질문이 사라지고 **repo variable이 `KAKAO_JS_KEY` → `KAKAO_REST_KEY`로 바뀐다.** 테스트 37건 통과.
>
> **수정 기록 (2026-09-04 ⑬)** — **Phase 2 구현 완료.** 세션 시작·종료·이어하기·`GET /internal/sessions/{id}`·F2-06 스케줄러 정리·`GET /api/me`의 `openSession`. **테스트 36건 통과**(Phase 1 18 + Phase 2 18). **막혀 있는 것은 Hume 키 3개뿐**이고, 자리표시가 들어 있어 **`POST /api/session/start`가 지금 503으로 떨어지는 것이 정상 동작**이다(그때 세션을 만들지 않는 것까지 확인). 구현 중 **문서 결함 2건을 잡았다.** ① **`resumableUntil`을 `ended_at + 30분`으로 계산할 수 없다** — `openSession`은 아직 열려 있는 세션이라 `ended_at`이 NULL이다. `started_at + 30분`으로 바꾸면 이번엔 **TC-22가 깨진다**(2분 말하고 죽은 뒤 5분 지나 이어하기하면 벽시계로 7분이 흘러 잔여 0). 앱이 죽으면 종료 신호가 없으므로 **서버가 아는 마지막 활동은 마지막 턴의 `occurred_at`뿐**이고, `usedSec`·이어하기 창·F2-06 정리를 전부 그 값 기준으로 고쳤다(계약 §2-2의 "중단 후 30분"과도 이쪽이 맞는다). ② **`resumedChatGroupId`를 채우는 주체가 어느 문서에도 없다** — EVI의 `chat_group_id`는 앱이 Hume과 직접 붙어 받는 값이라 백엔드가 알 수 없다. 지금은 항상 null이고 **이어하기는 되지만 맥락 복원만 안 된다.** `request/app/chat-group-id.md`(⏳)로 물었다 — P1이라 급하지 않다. **`POST /internal/summaries` 호출은 Phase 3으로 미뤘다** — 보낼 발화도, 그 본문을 평문으로 읽는 복호화 변환기도 Phase 3에서 생긴다. 지금 붙이면 실행되는 경로가 없는 코드가 남고, 계약 §2-5가 `summary: null`을 허용한다. 구현 중 결정 3건 — **내부 인증은 별도 필터**(`/internal/**`만, `MessageDigest.isEqual`로 비교) · **`HUME_CONFIG_ID`는 빈 문자열도 기동 실패**(대시보드에서 변수만 만들고 값을 안 넣는 쪽이 더 흔하다) · **`turn_log`는 엔티티 없이 집계만 읽는다**(Phase 2는 본문을 한 글자도 읽지 않는다).
>
> **수정 기록 (2026-09-04 ⑫)** — **Phase 1 구현 완료.** `backend/`에 Spring Boot 골격을 올렸다 — Java 21 · Boot 3.4.5 · Gradle · compose Postgres 16 · **11테이블 전부**. 구현: `POST /api/auth/kakao`(**`app_id` 대조 포함**) · `GET /api/me` · `GET /api/health`(DB에 실제로 닿는다) · JWT 필터 · CORS · 스케줄러 뼈대(5분). `DELETE /api/account`는 라우트만. **테스트 18건 통과**(단위 10 + 통합 8, compose DB에 붙어 `migration.sql`을 그대로 적용). 로컬 기동·헬스체크·프리플라이트·401 경로를 실제 서버로 확인했다. **남은 것은 실제 카카오 값 둘**(`KAKAO_APP_ID`·앱의 `KAKAO_JS_KEY`)이라 **로그인 끝단과 TC-01만 미검증**이다. 구현 중 결정 2건 — 서비스에 **인터페이스+Impl을 두지 않았고**(README 규칙), `Profile`은 생성자 대신 **`create()` 팩토리**를 쓴다(JPA 하이드레이션과 "새로 만든다"의 뜻이 겹치면 `createdAt`이 읽을 때마다 한 번 찍히고 덮인다).
>
> **수정 기록 (2026-09-04 ⑪)** — **Phase 1 착수 전 점검 — 문서에 근거 없이 비어 있던 6건을 결정했다.** ① **스케줄러 5분**(`fixedDelay`) — 뼈대를 만드는 Phase 1에 값이 없었다 ② **시크릿 등급 분리** — 셋을 같은 급으로 다루면 안 된다. `TRANSCRIPT_ENC_KEY`만 오프라인 사본을 두고 나머지 둘은 재발급으로 끝난다 ③ **카카오 동의항목 = 회원번호만**(콘솔에서 전부 비활성) ④ **탈퇴 시 카카오 unlink를 한다 — 앱이 SDK로.** Admin 키를 서버에 두지 않는다 ⑤ **테스트는 통합까지, 실DB는 기존 compose 재사용**(Testcontainers·H2 미채택) ⑥ **Supabase는 배포 시점에 만들고 Session pooler(5432)로 붙는다.** `ops_error_log`는 관리자 API를 만들지 않고 Supabase 대시보드 SQL로 본다. 아울러 **`HUME_SECRET_KEY`가 환경변수 목록에서 빠져 있던 것**을 잡아 AI 요청에 덧붙였다(단기 토큰 발급에 API 키와 짝으로 필요). 카카오 요청 2건은 문서를 새로 만들지 않고 **회신 대기 중인 `request/app/kakao-web-login.md` 스레드에 덧붙였다.**
>
> **수정 기록 (2026-09-04 ⑩)** — **소셜 로그인 방식을 점검했다.** 계약 §2-1·spec F1-01이 정한 것은 **액세스 토큰 전달 방식**(앱이 카카오 SDK로 로그인 → 토큰을 백엔드로 → 백엔드가 검증 → 자체 JWT, `Authorization: Bearer`)이고, 이 선택은 배포 구조가 강제한다 — 앱이 GitHub Pages, 백엔드가 Render라 **도메인이 완전히 달라서 쿠키 기반(리다이렉트+HttpOnly 쿠키) 방식은 서드파티 쿠키로 막힌다.** 점검하다 둘을 고쳤다. ① **`app_id` 대조가 문서에 없었다** — spec F1-01 ③이 "카카오 API로 토큰 검증" 한 줄이라, 그대로 짜면 `/v2/user/me`만 부르고 끝나 **아무 카카오 앱에서 발급된 토큰이든 통과한다.** `GET /v1/user/access_token_info`로 `app_id`를 대조하는 단계를 spec·`phase-1`에 명시했다. **정상 로그인만 해보면 안 잡히는 종류라** 완료 기준에도 넣었다. ② **`account.kakao_sub` → `kakao_id`** — 저장하는 값은 `/v2/user/me`의 `id`(회원번호)인데 `sub`은 OIDC 클레임 이름이라 이름과 값이 달랐다. 코드가 없는 지금이 고치는 비용이 0인 유일한 시점이다. **웹에서 액세스 토큰을 어떻게 얻는지는 앱 소관이라 `request/app/kakao-web-login.md`(⏳)로 물었다** — 인가 코드 방식이면 계약 §2-1이 바뀐다.
>
> **수정 기록 (2026-09-04 ⑨)** — **앱 요청 `cors-origin.md` 회신(✅)** — 앱이 GitHub Pages에 배포되며 오리진이 확정됐다. 허용 오리진은 **환경변수 목록**(`CORS_ALLOWED_ORIGINS`), 로컬은 `allowedOriginPatterns`로 `http://localhost:*`를 그대로 열어 **앱이 포트를 고정할 필요가 없다.** **회신하다 결함을 하나 잡았다 — `phase-1`의 JWT 필터 규칙("인증 제외 경로 2개 외 전부 필수")대로 짜면 `OPTIONS` 프리플라이트가 401로 막힌다.** 경로가 아니라 **메서드**로 예외를 둬야 한다. 앱이 요청서에 "프리플라이트는 인증 없이 통과해야 한다"를 명시해 준 덕에 구현 전에 걸렸다. 아울러 **Hume 계정 소유를 확정했다 — AI가 만들고 소유하며 결제도 그 계정 위에서 한다.** AI가 알려온 문제(`config_id`가 워크스페이스에 묶여 Config 계정과 결제 계정이 갈리면 쿼터가 적용되지 않음)의 팀 결정이다. 테스트·대시보드 확인이 전부 AI 쪽이라 계정을 그쪽에 두는 편이 왕복이 없다. **백엔드는 API 키와 `config_id`만 받는다.** 예산 상한은 **Creator 플랜**이고 콘솔 확인 4항목과 함께 `request/ai/hume-account-setup.md`(⏳)로 보냈다. **동시 접속만 보면 Starter(5)로 3인이 이미 충족**이라 상위 플랜의 값어치는 포함 분수·초과 단가에 있다(필요량 490분, PRD §11).
>
> **수정 기록 (2026-09-04 ⑧)** — **백엔드가 보낸 요청 2건에 회신이 왔다**(`../../docs/response/backend/`). ① **`turnIndex` 채번 ✅** — AI서버가 카운터를 세션 캐시 안에 두고 `lastTurnIndex`로 시드하므로 **0에서 시작하는 경로가 설계상 없다.** 이어하기는 유휴 60초로 감지해 재조회한다. 요청했던 `occurredAt` 확인은 **계약 v1.5 §3-2에 규칙으로 명시**됐다(발화 시각·밀리초·재시도 불변·세션 내 중복 없음) — **우리 중복 판별 가드의 전제가 계약으로 확정됐다.** 그래서 **`TURN_INDEX_COLLISION`은 이제 "정상 동작"이 아니라 "버그 신호"**다(한 건이라도 보이면 AI에 알린다). ② **통합 테스트 경로 ✅** — 터널 방식·순서 동의, **AI서버는 9/6 준비.** 터널 전에 쓸 고정 픽스처가 `ai-server/eval/fixtures/internal/`에 올라왔다. **그리고 새 블로커가 하나 왔다 — Hume Config를 만드는 계정과 결제하는 계정이 같아야 한다**(갈리면 결제한 쿼터가 적용되지 않는다). `roadmap.md` 착수 블로커 참조.
>
> **수정 기록 (2026-09-04 ⑦)** — 앞 회차에서 남긴 위험 두 개를 **기다리지 않고 닫았다.** ① **`/internal/turns` 중복 판별** — `unique` 위반 시 `occurred_at`을 비교해 재시도(무시)와 충돌(`max+1`로 저장 + `ops_error_log`)을 가른다. 종전에는 위반을 무조건 "이미 적재됨"으로 처리해, 이어하기 후 인덱스가 리셋되면 **새 발화가 오류 없이 사라졌다.** 이제 **AI 회신과 무관하게 유실이 0건이고 조용하지 않다** — 회신은 그 경로가 얼마나 자주 도느냐만 바꾼다. ② **미회신 요청을 놓친 원인을 지웠다** — 회신 현황에서 **개수와 완결 선언을 뺐다.** 손으로 베낀 숫자는 다음 요청이 오는 순간 틀리고, 그게 `tag-gap-endpoint.md`를 못 본 이유였다. **Phase 문서가 계약 스키마를 베껴 5곳이 어긋난 것과 같은 병이라 고치는 방향도 같다 — 규칙을 더하지 않고 베낀 것을 지운다.** 세는 방법은 `grep -L "✅" docs/request/backend/*.md` 하나로 두고 루트 `CLAUDE.md` 세션 시작 절에 넣었다.
>
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

## 남은 작업을 세는 법 — 문서에 개수를 적지 않는다

Phase를 끝낼 때마다 **못 한 것을 그 Phase 문서에 남긴다.** 체크박스는 `- [ ]`로 두고, 완료 기준은 `✅`/`⏳`로 표시하며, **왜 못 했고 누가 풀 수 있는지**를 그 줄에 같이 적는다.

세는 것은 문서가 아니라 명령이다.

```sh
grep -n "⏳" backend/docs/phase-*.md          # 끝내지 못한 완료 기준 (이유가 그 줄에 있다)
grep -n "^- \[ \]" backend/docs/phase-*.md   # 아직 안 한 작업
grep -L "상태: ✅" docs/request/*/*.md          # 회신을 기다리는 요청 (막고 있는 쪽)
```

> **`"✅"`만으로 찾으면 안 된다** (2026-09-05). 본문에 다른 문서를 가리키며 ✅를 한 번 적기만 해도 그 요청이 목록에서 사라진다 — 이 규칙을 쓴 다음 날 `kakao-rest-key-switch.md`가 실제로 그렇게 빠졌다. **배너 문자열(`상태: ✅`)로 찾는다.**

> **여기에 "남은 것 N건" 같은 요약표를 만들지 않는다.** 손으로 베낀 숫자는 다음 작업이 끝나는 순간 틀리고, 틀린 줄 모른 채 "다 했다"의 근거가 된다 — 백엔드가 `tag-gap-endpoint.md`를 놓친 경위가 정확히 그것이었다(루트 `CLAUDE.md` 세션 시작 절). **Phase 문서의 그 줄이 단일 출처다.**

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

**방향을 헷갈리지 말 것.** `../../docs/request/backend/`에 있는 문서는 **남이 백엔드에게 보낸 요청**이고, 회신은 **백엔드가 `../../docs/response/{요청자}/`에 쓴다.** 백엔드가 남에게 보낸 요청의 회신이 `../../docs/response/backend/`로 들어온다.

> **미회신 요청이 몇 건인지 이 파일에 적지 않는다.** 답은 파일 시스템에 있고, 여기 적은 숫자는 다음 요청이 도착하는 순간 틀린다 — 실제로 한 번 그렇게 놓쳤다(아래 "회신한 요청"). **세는 방법은 하나다.**
>
> ```sh
> git pull && grep -L "✅" docs/request/backend/*.md   # 루트에서. README.md는 무시
> ```

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
| 기록 목록 범위 (2026-09-05) | **끝난 세션만** | `phase-5` 5-5 | 진행 중인 대화가 목록에 뜨면 "지난 대화"로 읽힌다. 이어하기 제안은 `GET /api/me`의 `openSession`이 맡는다 |
| `highlights` 구간 연결 (2026-09-05) | **기록 없는 날에서 끊는다** | `phase-5` 5-4 | 이어 붙이면 대화가 없던 날까지 "갭이 높았던 기간"으로 칠한다 — 없는 감정을 그리지 않는다(§1-3) |
| 같은 태그 관찰 중복 (2026-09-05) | **활성 관찰이 있으면 새로 만들지 않는다** | `phase-4` 완료 기준 | 집계가 전체 기간이라 한 번 넘긴 태그는 세션마다 계속 넘긴다. 그대로 두면 발견 화면이 같은 문장으로 도배되고 AI 호출도 매번 나간다. **spec에 규정이 없던 부분** — 갱신 방식은 도그푸딩 뒤에 정한다 |
| 중복 적재 판별 방식 (2026-09-05) | **먼저 조회**(위반을 잡아 되살리지 않는다) | `phase-3` 3-1 | 제약 위반은 트랜잭션을 롤백 전용으로 만들어 같은 트랜잭션에서 재번호 저장을 못 한다. 인덱스 조회 한 번이 그 복잡함보다 싸다 |
| 깨진 요청 본문 (2026-09-05) | **500 → 400 `VALIDATION_ERROR`** | `GlobalExceptionHandler` | 계약 §3-2에서 AI는 5xx를 3회 재시도한다. 깨진 본문은 재시도해도 같은 결과이고, 원인이 "백엔드가 죽었다"로 보인다. **파서 메시지는 로그에 넣지 않는다** — 본문 조각이 곧 발화다 |
| `ops_error_log` 트랜잭션 (2026-09-05) | **`REQUIRES_NEW`** | `OpsErrorLogger` | 오류를 남기는 쪽은 대개 롤백되는 경로다. 같은 트랜잭션에 실으면 "왜 실패했는지"가 함께 사라진다 |
| 보조 테이블 접근 (2026-09-05) | `turn_tag`·`crisis_event`·`ops_error_log`는 **엔티티 없이 JdbcTemplate** | `phase-3` | Phase 3은 쓰기만 하고, Phase 4의 집계는 `group by` SQL이라 엔티티를 거치지 않는다 |
| 카카오 로그인 방식 (2026-09-05) | **인가 코드 교환.** 앱은 인가 URL로 보내기만 하고 서버가 REST 키 + 시크릿으로 교환 | 계약 §2-1 v1.6, `spec.md` F1-01, `phase-1` 1-6 | 웹에서는 앱이 액세스 토큰을 받을 수 없다(SDK 2.0.1 소스). 덤으로 키가 서버에만 남고 `app_id` 대조가 불필요해진다 |
| `redirectUri` 검증 (2026-09-05) | **등록 목록과 대조, 아니면 400** | `phase-1` 1-6, `KakaoOAuthService` | 카카오에 그대로 전달되는 값이라 열어두면 남의 주소로 인가받은 코드를 우리 서버로 교환시킬 수 있다 |
| 탈퇴 unlink 담당 (2026-09-05) | **백엔드.** 앱이 탈퇴 시점 인가 코드를 §2-3 선택 본문으로 넘긴다 | `spec.md` F10-03, `phase-6`, 계약 §2-3 | 코드 방식에서는 앱에 카카오 자격증명이 없다. **Admin 키·리프레시 토큰 둘 다 쓰지 않는다** — 토큰 보관은 전 사용자의 2개월 자격증명을 들고 있는 것이라 "회원번호 하나만 저장" 주장과 어긋난다 |
| 이어하기 창·`usedSec` 기준 | **마지막 턴의 `occurred_at`** (없으면 `started_at`) | `data-model.md`, `phase-2-session.md` 2-4·2-5 | `ended_at`은 열린 세션에서 NULL이라 계산 불가. `started_at` 기준은 TC-22를 깬다 — 앱이 죽으면 종료 신호가 없으므로 서버가 아는 마지막 활동은 이 값뿐이다 |
| `/internal/**` 인증 | **별도 필터**(JWT 필터는 `/internal/`을 건너뛴다) | `phase-2-session.md` 2-2 | 인증 수단이 다르다(공유 시크릿 vs JWT). 한 필터에 두 갈래를 넣으면 한쪽 경로 변경이 다른 쪽을 조용히 뚫는다. 비교는 `MessageDigest.isEqual` |
| `HUME_CONFIG_ID` 검증 | **빈 문자열도 기동 실패** | `SessionPolicy` | 계약 §2-4가 null 불가. 미설정보다 **대시보드에 변수만 만들고 값을 안 넣는 쪽이 흔하다** |
| `turn_log` 접근 | **Phase 2는 엔티티 없이 집계만**(JdbcTemplate) | `phase-2-session.md` | 본문을 한 글자도 읽지 않는다. 평문이 필요한 시점은 복호화 변환기가 붙는 Phase 3이고, 그전에 엔티티를 만들면 복호화 없는 조회 경로가 먼저 생긴다 |
| 세션 시작 순서 | **Hume 토큰 발급 → 이전 세션 닫기 → 세션 생성** | `phase-2-session.md` 2-1 | 뒤집으면 발급 실패 때 사용자가 대화도 못 시작하고 이어하기 대상까지 잃는다 |
| `POST /internal/summaries` 호출 | **Phase 3으로 이동** | `phase-2-session.md` 2-3, `api-spec.md` | 보낼 턴도 복호화 변환기도 Phase 3에서 생긴다. 계약 §2-5가 `summary: null`을 허용한다 |
| 임계값 모드 전환 기준 | `session_count < 5` → `fixed`, `>= 5` → `personal`(개인 평균 ± 표준편차) | `spec.md` F3-04 | 고정 단독은 목소리가 원래 낮은 사용자에게 매번 오탐. 개인 baseline 단독은 첫 사용자 데모가 작동하지 않음 |
| 미종료 세션 정리 주기 | **마지막 발화 후 30분** 경과 → `timeout` 종료 (2026-09-04 정정, 위 첫 행)(그대로 배치 미처리 상태가 된다). F11-02 헬스체크와 같은 스케줄러 | `spec.md` F2-06 | 추가 인프라 없이 중단된 대화의 배치 유실을 막음 |
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
| **`/internal/turns` 중복 판별 (2026-09-04 ⑦)** | **`unique` 위반 시 `occurred_at`을 비교한다.** 같으면 재시도(무시), 다르면 충돌(`max+1`로 저장 + `ops_error_log`). 둘 다 202 | `phase-3-turn-ingest.md` 3-1, `data-model.md` | 위반을 무조건 "이미 적재됨"으로 보면 **이어하기 후 인덱스 리셋 시 새 발화가 조용히 사라진다.** 재시도는 같은 페이로드를, 충돌은 다른 발화를 보내므로 컬럼 하나로 갈린다. **AI 회신을 기다리지 않고 유실을 막고**, 원인이 이어하기가 아니어도 같이 막힌다. 전제는 `occurredAt`이 발화 시각이고 재시도에서 불변이라는 것 — AI에 확인 중(`request/ai/turn-index-numbering.md` 3번) |
| **스케줄러 주기 (2026-09-04 ⑪)** | **5분, `fixedDelay`** | `phase-1-skeleton.md` 1-7 | F2-06이 "30분 경과"를 판정하므로 오차가 최대 5분이고, `resumableUntil`이 그 시각과 같아서 이어하기 창도 그만큼만 밀린다. **1분은 빈 스캔이 60배**(관찰은 3회·1.5배 조건이라 매번 안 생긴다), **10분은 이어하기 창이 40분까지 밀린다.** `fixedRate`가 아닌 이유는 배치가 길어질 때 겹쳐 도는 것을 막기 위함 |
| **시크릿 보관 등급 (2026-09-04 ⑪)** | 셋 다 `openssl rand -base64 32`. **`TRANSCRIPT_ENC_KEY`만 저장소 밖 오프라인 사본 1부**, 나머지 둘은 Render 환경변수만. 로컬·배포 키 분리 | `phase-1-skeleton.md` 1-3-1 | `JWT_SECRET`·`INTERNAL_SHARED_SECRET`은 **재발급하면 끝**이지만 암호화 키는 **그 키로 암호화된 데이터를 되살릴 방법이 없다.** 셋을 같은 급으로 다루면 정작 중요한 하나가 묻힌다 |
| **카카오 동의항목 (2026-09-04 ⑪)** | **회원번호만.** 닉네임·프로필 사진·이메일 전부 비활성 | `spec.md` F1-01, `request/app/kakao-web-login.md` | `account`에 회원번호 말고 담을 컬럼이 없어 **받아도 버린다.** PRD §5.1 "식별자 분리"가 콘솔 설정으로도 증명되고, 동의 화면이 짧아져 첫 화면 이탈이 준다. **나중에 열면 기존 사용자는 재동의**라 지금 정하는 게 맞다 |
| **탈퇴 시 카카오 unlink (2026-09-04 ⑪)** | **한다. 앱이 SDK로**, 백엔드 204를 받은 **뒤에** | `spec.md` F10-03, `phase-6-data-lifecycle.md` | DB만 지우면 카카오 "연결된 서비스"에 앱이 남아 "모두 지웠다"가 절반만 참이 된다. 서버에서 하려면 **모든 사용자를 조작할 수 있는 Admin 키**가 필요한데 앱은 본인 토큰으로 자기 것만 끊는다. **삭제가 먼저인 이유**는 순서를 뒤집으면 "카카오는 끊겼는데 데이터는 남은" 상태가 생기기 때문 |
| **테스트 범위·DB (2026-09-04 ⑪)** | **통합 테스트까지.** 실DB는 **기존 compose Postgres 재사용**(테스트 전용 DB 이름 + 트랜잭션 롤백) | `phase-1-skeleton.md` 1-9 | Testcontainers의 값어치는 "외부 상태 비의존"인데 **백엔드에 CI가 없어** 어차피 내 PC에서만 돈다 — 의존성만 는다. H2는 `gen_random_uuid()`·`jsonb`·부분 인덱스·`timestamptz`에서 다르게 동작하는데 **검증하려는 게 정확히 그 부분**이라 통과하고 배포에서 깨진다. compose 재사용은 `migration.sql`을 그대로 적용해 **스키마까지 같은 파일로 검증**된다 |
| **Supabase 시점·연결 (2026-09-04 ⑪)** | **배포 시점에 생성. Session pooler(5432).** `ops_error_log`는 관리자 API 없이 대시보드 SQL로 조회 | `phase-7-ops-deploy.md` 7-4 | 미리 만들면 무료 플랜이 1주 미사용에 일시정지돼 깨우는 절차만 는다(로컬은 compose로 충분했다). **Transaction pooler(6543)는 prepared statement 미지원**이라 JPA·HikariCP와 부딪히고, 직결은 IPv6 경로 문제가 있다. 관리자 API는 3인 규모에 값어치가 없고 **만들면 그 API가 인증·권한 설계 대상**이 된다 |
| **소셜 로그인 방식 (2026-09-04 ⑩)** | **액세스 토큰 전달 방식.** 앱이 카카오 SDK로 로그인해 토큰을 보내면 백엔드가 검증하고 자체 JWT를 **응답 바디로** 준다. 리다이렉트+쿠키 방식 미채택 | `spec.md` F1-01·F1-02, `api-contract.md` §2-1·§1-1 | 앱(GitHub Pages)과 백엔드(Render)의 **도메인이 완전히 달라 쿠키가 서드파티가 된다** — `SameSite=None; Secure`로 심어도 브라우저 정책에 막힌다. 쿠키를 쓰면 `Allow-Credentials`를 켜야 하고 그러면 `localhost:*` 와일드카드 오리진도 못 쓴다(CORS 결정과 충돌). Bearer 토큰이 이 배포 구조에서 강제되는 쪽이다 |
| **카카오 토큰 검증 절차 (2026-09-04 ⑩)** | **`access_token_info`로 `app_id` 대조 → `/v2/user/me`로 회원번호.** 대조 실패는 401 | `spec.md` F1-01, `phase-1-skeleton.md` 1-6 | `/v2/user/me`는 "이 토큰이 어느 앱 것인지"를 묻지 않는다. 카카오 앱은 누구나 만들 수 있으므로 **출처를 확인하지 않으면 우리가 발급하지 않은 신원을 받아들인다.** 호출 한 번이고, **빠뜨려도 정상 로그인은 멀쩡히 돼서 테스트로는 안 잡힌다** |
| **`account.kakao_id` 명칭 (2026-09-04 ⑩)** | `kakao_sub` → **`kakao_id`** | `spec.md` §6-1, `data-model.md` | 저장하는 값은 `/v2/user/me`의 `id`(회원번호)다. `sub`은 OIDC ID 토큰 클레임이고 우리는 OIDC를 쓰지 않는다. 이름과 값이 다르면 구현할 때 한 번 멈춘다. **백엔드 내부 컬럼이라 앱·AI 영향 0**, 코드가 없는 지금이 비용 0인 유일한 시점 |
| **CORS (2026-09-04 ⑨)** | **오리진은 환경변수 목록**(`CORS_ALLOWED_ORIGINS`). `allowedOriginPatterns`로 `http://localhost:*` 허용, `Allow-Credentials`는 끔. **`OPTIONS`는 JWT 필터에서 메서드 단위로 예외** | `phase-1-skeleton.md` 1-6·1-6-1, `response/app/cors-origin.md` | 커스텀 도메인이 붙으면 오리진이 한 번 더 바뀌는데(PRD §14-6) 코드에 박으면 그때 재배포다. 계약서에는 넣지 않았다 — **CORS는 배포 설정이지 인터페이스 필드가 아니고**, 특정 오리진을 계약에 적으면 필드가 하나도 안 바뀌는데 버전을 올려야 한다. 프리플라이트 예외를 메서드로 두는 이유는 `OPTIONS`에 `Authorization`이 안 실리기 때문이고, **이 실패는 앱에 네트워크 오류로만 보여 원인 추적이 오래 걸린다** |
| **Hume 계정 소유 (2026-09-04 ⑨)** | **AI가 만들어 소유하고 결제도 그 계정 위에서.** 백엔드는 API 키·`config_id`만 받는다. 예산 상한 Creator 플랜 | PRD §14-3, `request/ai/hume-account-setup.md` | `config_id`가 워크스페이스에 묶여 **계정이 갈리면 결제한 쿼터가 적용되지 않는다** — 대화는 붙고 5분 뒤 끊기며 원인이 코드로 안 보인다. 테스트·대시보드가 전부 AI 쪽이라 계정을 그쪽에 두면 Config 설정마다 생기는 왕복이 없어진다. **동시 접속은 Starter(5)로 3인 충족**이므로 플랜 선택 기준은 490분(PRD §11)을 어디가 싸게 넘기는지다 |
| **`occurredAt` 보장 (2026-09-04 ⑧, AI 회신)** | **발화 시각 · 밀리초 정밀도 · 재시도 시 동일 문자열 · 같은 세션에서 값 중복 없음.** AI서버가 값이 겹치면 1ms를 더한다 | `api-contract.md` §3-2 (**v1.5**), `response/backend/turn-index-numbering.md` | 우리 중복 판별 가드가 이 필드 하나에 걸려 있었는데 계약엔 예시만 있었다. 규칙이 명시되어 **가드가 오판할 경로가 사라졌다.** 다만 AI서버 시계로 찍혀 **실제 발성보다 수백 ms 뒤**이므로 발화 간격 분석에는 쓰지 않는다 |
| **`TURN_INDEX_COLLISION`의 위상 (2026-09-04 ⑧)** | **정상 동작이 아니라 버그 신호.** 한 건이라도 나오면 AI에 알린다 | `phase-3-turn-ingest.md` 3-1, `response/backend/turn-index-numbering.md` | AI가 `lastTurnIndex` 시드 + 유휴 60초 재조회로 리셋 경로를 막았으므로 **이어하기에서도 이 로그가 안 나와야 한다.** 가드는 데이터를 지키는 그물이지 상시 경로가 아니다 |
| **로그 상관 수단 (2026-09-04 ⑥)** | **`sessionRef = SHA-256(sessionId)[:8]`.** `ops_error_log.message` 앞머리·앱 로그·`traceId`에 같은 값 | `data-model.md`, 절대 원칙 6번 | 발화도 `sessionId`도 못 남기면 `/internal/turns` 실패를 추적할 수단이 0이다. 해시는 인증에 쓸 수 없어 원칙 6번(CLM 인증 수단 노출 금지)을 깨지 않는다. 컬럼도 안 늘어난다 |

### 회신한 요청 (이력 — 현황이 아니다)

회신은 백엔드가 `../../docs/response/{요청자}/`에 **요청과 같은 파일명**으로 썼다. 요청 본문은 고치지 않고 요청 문서의 상태 배너만 ✅로 바꿨다. 앞의 네 건은 계약서를 **v1.3 하나로 묶어**, 다섯째는 **v1.4**로 개정했다.

| 요청 | 회신 | 반영 |
| --- | --- | --- |
| [`hume-config-id.md`](../../docs/request/backend/hume-config-id.md) | [`response/app/hume-config-id.md`](../../docs/response/app/hume-config-id.md) | `humeConfigId` 필드 추가 (기동 시 fail-fast) |
| [`session-context-lookup.md`](../../docs/request/backend/session-context-lookup.md) | [`response/ai/session-context-lookup.md`](../../docs/response/ai/session-context-lookup.md) | §3-4 신설, CLM 인증 확정, `sessionId` UUID화 |
| [`live-turn-signal.md`](../../docs/request/backend/live-turn-signal.md) | [`response/app/live-turn-signal.md`](../../docs/response/app/live-turn-signal.md) | §2-13 신설(폴링), 재시도 3회 |
| [`session-summary-endpoint.md`](../../docs/request/backend/session-summary-endpoint.md) | [`response/ai/session-summary-endpoint.md`](../../docs/response/ai/session-summary-endpoint.md) | §3-5 신설(동기 3초) |
| [`tag-gap-endpoint.md`](../../docs/request/backend/tag-gap-endpoint.md) (2026-09-04) | [`response/app/tag-gap-endpoint.md`](../../docs/response/app/tag-gap-endpoint.md) | §2-8에 `tagGaps`·`userAvgGap` 추가 (v1.4) |
| [`cors-origin.md`](../../docs/request/backend/cors-origin.md) (2026-09-04) | [`response/app/cors-origin.md`](../../docs/response/app/cors-origin.md) | 오리진 환경변수화, 포트 고정 불필요. **JWT 필터의 `OPTIONS` 결함을 구현 전에 잡음** |

### 백엔드가 보낸 요청 (추가)

| 요청 | 대상 | 내용 |
| --- | --- | --- |
| [`request/app/kakao-web-login.md`](../../docs/request/app/kakao-web-login.md) ⏳ (2026-09-04) | 앱 | 웹에서 카카오 **액세스 토큰**을 얻는지 **인가 코드**를 얻는지. 후자면 **계약 §2-1 개정**이 필요하다. 막지는 않는다 |

> **이 표는 "무엇을 어떻게 회신했나"라는 이력이다. "남은 게 있나"의 답이 아니다.**
>
> `tag-gap-endpoint.md`를 놓칠 뻔했다. 이 폴더를 전면 재작성한 뒤에 도착했는데, 재작성본이 **"4건 전부 회신 완료"라고 못박아둔 탓에 다음에 이 파일을 읽을 때 새 요청을 찾을 이유가 사라져 있었다.** 표가 틀린 게 아니라 **쓴 순간에는 맞았고 그 뒤에 낡았다** — 손으로 베낀 사실은 전부 그렇게 된다.
>
> **Phase 문서가 계약 스키마를 베껴서 5곳이 어긋난 것과 같은 병이다**(결정 로그 "Phase 문서의 스키마 복제"). 고치는 방향도 같다 — **규칙을 더하지 않고 베낀 것을 지운다.** 그래서 이 절에서 개수와 완결 선언을 뺐다. 숫자가 없으면 낡을 수 없다.

### 백엔드가 보낸 요청

`../../docs/response/backend/`로 회신이 들어온다. **현황은 `grep -L "✅" docs/request/ai/*.md`로 센다** — 아래 표도 이력이다.

| 요청 | 회신 | 결과 |
| --- | --- | --- |
| [`request/ai/integration-test-path.md`](../../docs/request/ai/integration-test-path.md) | [`response/backend/integration-test-path.md`](../../docs/response/backend/integration-test-path.md) ✅ | 터널 방식·순서 동의. **AI서버 9/6 준비**, 고정 픽스처 제공. **Hume 계정 일치 문제를 새로 알려왔다** |
| [`request/ai/turn-index-numbering.md`](../../docs/request/ai/turn-index-numbering.md) | [`response/backend/turn-index-numbering.md`](../../docs/response/backend/turn-index-numbering.md) ✅ | 확인 3건 전부 확인. `occurredAt` 규칙을 **계약 v1.5**에 명시 |
| [`request/ai/hume-account-setup.md`](../../docs/request/ai/hume-account-setup.md) ⏳ (2026-09-04) | — | 계정 소유·예산 상한 통보 + 콘솔 확인 4항목. **Phase 2의 `session/start` 실동작과 9/6 EVI 통합을 막는다** |

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
