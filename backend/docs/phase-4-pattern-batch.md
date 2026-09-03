# Phase 4 — 패턴 배치

의존: Phase 3(턴 로그·태그)가 쌓여 있어야 의미 있는 배치가 돈다.

## 체크리스트

- [ ] `observation`, `observation_evidence` 테이블 — 근거: spec §6-1
- [ ] 배치 트리거 — 세션 종료(Phase 2의 F2-05) 시 큐 적재, 비동기 실행. **배치 실패가 대화·조회 기능에 영향을 주지 않는다** — 근거: spec F7-01
- [ ] 태그별 집계 — 사용자 전체 기간 태그별 등장 횟수·평균 갭/개인 전체 평균 갭 산출. 갭 `null` 턴 제외 — 근거: spec F7-02
- [ ] **규칙 판정 (결정적, LLM 호출 없음)** — `occurrences >= 3 AND tagAvgGap >= userAvgGap × 1.5`. 미달 시 관찰을 만들지 않는다 — 근거: spec F7-03. **이 조건 판정에 LLM을 절대 섞지 않는다** — 루트 `CLAUDE.md` 절대 규칙
- [ ] `POST /internal/observations` 호출 — 판정 통과한 집계 **숫자만** AI서버에 전달해 문장 생성 요청. 판정 자체는 이미 끝난 뒤라 AI서버 응답은 표현(문장)만 바뀔 뿐 판정에 영향 없음 — 근거: spec F7-04, api-contract §3-3
- [ ] evidence 부착 — `observation.evidence`(집계 숫자) + `observation_evidence`(근거 turn 연결). API 응답에는 turn ID를 넣지 않는다 — 근거: spec F7-05, api-contract §2-6·2-7

## 완료 기준

- TC-16 (태그 2회만 등장 → 관찰 미생성, 침묵)
- TC-17 (관찰 카드 → 근거 열람: evidence 숫자와 실제 대화 건수 일치)
- 관찰 문장 ↔ evidence 숫자 불일치 0건 (§1.4 핵심 지표)
