# 백엔드 Request

백엔드 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- API 신규/수정 요청, 데이터 모델 변경, 서버 로직 관련 요청 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `session-resume-contract.md`, `turn-log-schema-update.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 반영 |
| --- | --- | --- |
| [deploy-secret-handoff.md](deploy-secret-handoff.md) | ⏳ **회신 대기** (2026-09-07, 요청자 AI) | **배포용 `INTERNAL_SHARED_SECRET` 하나가 대화 전체를 막고 있다.** AI서버는 배포됐고(`…run.app`) 백엔드에 닿는 것까지 확인했는데 인증에서 401. 로컬 값으로는 거부되는 것을 실물로 확인했다. 받으면 10분이면 끝난다 |
| [cors-on-401.md](cors-on-401.md) | ✅ **회신 완료** (2026-09-06) | ~~필터가 만드는 401에만 CORS 헤더가 없어 앱이 인증 실패를 볼 수 없다~~ → **`CorsConfig`가 `WebMvcConfigurer`(MVC 계층)라 `JwtAuthFilter`가 그 앞에서 만든 401은 처리를 안 탔다.** `CorsFilter`를 `HIGHEST_PRECEDENCE`로 앞에 두어 해결. 배포본 확인 완료, 회귀 테스트 2건 |
| [session-id-in-url.md](session-id-in-url.md) | ✅ **회신 완료** (2026-09-05) | 앱이 S05-1 경로에 `sessionId`를 싣는다. §1-1이 이 값을 "비밀과 동급"으로 규정 — **이대로 둘지, 공개용 식별자를 따로 둘지** 결정 필요. 막는 작업은 없음 |
| [cors-origin.md](cors-origin.md) | ✅ **회신 완료** (2026-09-04) | 허용 오리진·프리플라이트·자격증명 확정. `response/app/cors-origin.md`. 계약 개정 없음(배포 설정) |
| [tag-gap-endpoint.md](tag-gap-endpoint.md) | ✅ **회신 완료** (2026-09-04) | `GET /api/trend`에 `tagGaps`·`userAvgGap` 신설. `response/app/tag-gap-endpoint.md`, 계약 v1.4 §2-8 |
| [hume-config-id.md](hume-config-id.md) | ✅ **회신 완료** (2026-09-03) | `humeConfigId` 필드 신설. `response/app/hume-config-id.md`, 계약 v1.3 |
| [live-turn-signal.md](live-turn-signal.md) | ✅ **회신 완료** (2026-09-03) | `GET /api/session/{id}/live` 신설(폴링). `response/app/live-turn-signal.md`, 계약 v1.3 §2-13 |
| [session-context-lookup.md](session-context-lookup.md) | ✅ **회신 완료** (2026-09-03, 요청자 AI) | `GET /internal/sessions/{id}` 신설, CLM 인증 확정(`custom_session_id` 검증). `response/ai/session-context-lookup.md`, 계약 v1.3 §3-4·§4 |
| [session-summary-endpoint.md](session-summary-endpoint.md) | ✅ **회신 완료** (2026-09-03, 요청자 AI) | `POST /internal/summaries` 신설(동기 3초). `response/ai/session-summary-endpoint.md`, 계약 v1.3 §3-5 |
