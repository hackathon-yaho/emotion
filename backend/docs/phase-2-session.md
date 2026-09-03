# Phase 2 — 대화 세션

의존: Phase 1(인증)의 JWT 필터.

## 체크리스트

- [ ] `voice_session` 테이블 — `id`는 **UUID(v1.3 확정)**, `sessionId`를 로그에 남기지 않는다(CLM 인증 겸용 — 백엔드 절대 원칙 6번) — 근거: spec §6-1, api-contract §1-1
- [ ] `POST /api/session/start` — `voice_session` 생성(UUID 발급) → `user_baseline.session_count` 조회 → 임계 모드 결정(`fixed`/`personal`, Phase 3의 `user_baseline`과 연결) → Hume 단기 액세스 토큰 발급 → `humeConfigId`(환경변수, 기동 시 없으면 fail-fast) · `livePollIntervalSec`(2초) 포함해 응답 — 근거: spec F2-01, F3-04, api-contract §2-4 (v1.3)
- [ ] 새 세션 시작 시 그 사용자의 열린 세션을 먼저 닫는다(동시 세션 처리) — 근거: spec F2-06
- [ ] `POST /api/session/{id}/end` — 종료 시각·길이 기록, `end_reason` 저장, **F7-01 배치 큐 적재**. `endReason`이 `user_end`·`soft_wrap`·`hard_cut`이면 §3-5 `POST /internal/summaries` **동기 호출**(타임아웃 3초, 실패 시 null), **`timeout`이면 호출하지 않고 항상 null** — 근거: spec F2-05, api-contract §2-5 (v1.3)
- [ ] 미종료 세션 자동 정리 스케줄러 — 시작 후 30분 경과 시 `timeout`으로 종료 + 배치 큐 적재(요약 생성 없이). **Phase 1의 헬스체크 스케줄러에 태운다**(추가 인프라 0) — 근거: spec F2-06
- [ ] `GET /api/me`의 `openSession` 필드 채우기 (Phase 1에서 만든 뼈대에 연결) — 근거: spec F2-07
- [ ] `POST /api/session/{id}/resume` (P1) — 잔여 시간 = `hardCutSec − usedSec`(새 7분 지급 안 함), `humeConfigId` 재포함(같은 Config로 재연결), 이어하기 창 30분 경과 시 409 `SESSION_NOT_RESUMABLE` — 근거: spec F2-07, api-contract §2-5-1 (v1.3)
- [ ] Hume API 키가 응답 어디에도 노출되지 않는지 확인 (토큰만 발급) — 근거: spec F2-01 수용 기준
- [ ] `GET /internal/sessions/{sessionId}` (§3-4, v1.3) — AI서버가 세션당 1회 조회하는 CLM 인증 겸 컨텍스트 조회. `status`·`startedAt`·`usedSec`·`thresholdMode`·`gapThreshold`·`softWrapSec`·`hardCutSec`·`demoMode`·`recentObservations`(F8 대비, 지금은 빈 배열) 반환. **모르는 ID·`ended`도 200**(401 전환은 AI서버 몫) — 근거: api-contract §3-4·§4

## 결정 완료 (2026-09-03 회신 반영, 상세는 `README.md` 결정 로그)

- **`sessionId` = UUIDv4, 접두사 없음.** CLM 인증(§3-4)에 쓰이므로 128비트 미만 형식 금지
- **CLM 인증 = `custom_session_id` 검증(§3-4).** `language_model_api_key` 미사용
- **`GET /internal/sessions/{id}` 조회 실패는 fail-closed** — AI서버가 세션당 1회 조회 후 `hardCutSec+30분` 캐시. 캐시 미스+백엔드 장애는 401(잃는 가용성 없음 — 백엔드가 죽으면 `session/start`도 죽어 새 세션이 안 생김)
- **`humeConfigId` 없으면 기동 시 fail-fast.** 런타임 503이 아니다

## ⚠️ 남은 과제 (결정 아님, 착수 필요)

- **Hume 유료 플랜 실측** — 앱이 콘솔에서 확인한 바로 **Free 티어는 월 5분**이다. 9/10 도그푸딩(90분 예상)에 쓸 수 없으므로 **결제 전에 플랜·단가를 실측**해야 한다. 추가 사용료도 PRD §11 표기($0.07/분)와 다른 $0.06/분으로 적혀 있어 원가 계산이 함께 걸린다. PRD §14-3이 백엔드 과제로 잡아둔 항목 — `response/app/hume-config-id.md`에서 확인 회신함

## 완료 기준

- TC-02 (대화 시작 → 3분 대화 → 종료: 세션·턴 로그 정상 적재, 요약 표시)
- TC-03 (Hume API 키 미노출)
- TC-07 (5회차 세션 진입 시 `thresholdMode`가 `personal`로 전환 — Phase 3의 baseline 갱신과 함께 확인)
- TC-21 (앱 강제 종료 → 30분 대기 → 세션이 `timeout`으로 종료되고 배치에 반영)
- TC-22 (앱 강제 종료 → 5분 뒤 재진입 → 이어하기: 남은 시간이 잔여분)
