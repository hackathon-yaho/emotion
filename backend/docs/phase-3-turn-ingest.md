# Phase 3 — 턴 로그 수신

의존: Phase 2(세션)의 `voice_session`.

## 체크리스트

- [ ] `turn_log`, `turn_tag`, `user_baseline` 테이블 — 근거: spec §6-1
- [ ] `POST /internal/turns` 수신 — 내부 공유 시크릿 인증, AI서버로부터 턴마다 비동기 수신 — 근거: spec F5-01, api-contract §3-1·3-2
- [ ] `transcript` 암호화 저장 (`turn_log.transcript_enc`) — DB를 직접 조회해도 평문이 보이지 않아야 함 — 근거: spec F5-02
- [ ] 태그 저장 (`turn_tag`) — AI서버가 이미 원문 대조를 마친 태그를 그대로 저장. **백엔드가 태그를 추가·수정·재검증하지 않는다** — 근거: spec F6-03
- [ ] `user_baseline` 갱신 — 세션 종료 시 개인 평균 갭·표준편차 재계산, 갭 `null`인 턴은 집계 제외 — 근거: spec F3-05
- [ ] 임계값 모드 결정 로직 확정 — `session_count < 5` → `fixed` / `>= 5` → `personal`(Phase 2의 세션 시작 API가 이 값을 읽음) — 근거: spec F3-04
- [ ] 전송 실패해도 대화에 영향 없는지 확인 — 백엔드가 다운돼도 앱·AI서버 쪽 대화는 정상 진행돼야 함 (이 Phase 관점에서는 수신 실패 시 AI서버가 어떻게 재시도하는지가 아니라, **수신 엔드포인트 자체가 느리게 응답하지 않는지**만 확인). **재시도는 1회 → 3회로 상향(v1.3)** — 근거: spec F5-04, api-contract §3-2

## 결정 완료 (2026-09-03 회신 반영)

`GET /internal/sessions/{sessionId}`(§3-4)가 **Phase 2로 구현이 옮겨졌다** — 세션 시작·조회 API와 같은 자리라서다. 그 결과 여기서 받는 `/internal/turns`의 `thresholdMode`는 **AI서버가 Phase 2의 조회로 정확한 값을 알고 보내는 값**이 된다(더 이상 `.env` 고정값 우회가 아니다). 상세 결정은 `README.md` 결정 로그와 `response/ai/session-context-lookup.md` 참조.

## 완료 기준

- TC-06 (분석 호출 타임아웃·실패 강제 시: 갭 미산출, 태그 없음으로 정상 수신)
- TC-11 (대화 전 구간 감사: 서버·스토리지에 오디오 파일 0건 — 이 Phase가 오디오를 다루지 않는지 확인)
- TC-15 (원문에 없는 태그가 저장되지 않음 — AI서버가 이미 걸렀다는 전제를, 실제 수신 데이터로도 확인)
