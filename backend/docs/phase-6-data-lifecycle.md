# Phase 6 — 데이터 관리 (삭제 · 탈퇴)

의존: Phase 2~5의 테이블이 전부 존재해야 삭제·연쇄 무효화가 의미 있다. 마지막에 붙여도 되지만, **F1-04·DELETE /api/account 라우트는 Phase 1에서 이미 등록해 둔 상태**다.

## 체크리스트

- [ ] `DELETE /api/sessions/{id}` — `turn_log`·`turn_tag` 삭제 → 연쇄 무효화(아래) → `user_baseline` 재계산(Phase 3의 F3-05 로직 재사용) — 근거: spec F10-01, api-contract §2-11
- [ ] 관찰 연쇄 무효화 — 삭제된 turn을 evidence로 참조하던 관찰 조회 → **남은 근거가 3회 미만이면 관찰 삭제**, 이상이면 evidence 숫자 재계산 — 근거: spec F10-02
- [ ] `DELETE /api/account` 실제 로직 — `account`, `account_profile`, `profile`, `voice_session`, `turn_log`, `turn_tag`, `user_baseline`, `observation`, `observation_evidence`, `crisis_event` **단일 트랜잭션** 삭제. `ops_error_log`는 제외 — 근거: spec F10-03, F1-04
- [ ] 부분 삭제 실패 시 트랜잭션 롤백 (부분 삭제 상태를 만들지 않는다) — 근거: spec F1-04

## 완료 기준

- TC-13 (탈퇴 후 재가입 → 신규 사용자로 시작, 이전 데이터 0건)
- TC-19 (근거 대화 삭제 → 관찰 삭제 또는 숫자 재계산, 불일치 0건)
- 삭제 후 해당 대화가 대화기록 목록·트렌드 집계 어디에도 남지 않는다
