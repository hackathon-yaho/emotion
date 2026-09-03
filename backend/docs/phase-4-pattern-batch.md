# Phase 4 — 패턴 배치

> 목표: **쌓인 턴에서 관찰이 생기는 상태**를 만든다. 조회 화면은 아직 없어도 된다.
>
> 의존: Phase 3이 적재한 `turn_log`·`turn_tag` 데이터 · Phase 1의 스케줄러 뼈대와 `observation`·`observation_evidence` 테이블 · Phase 2가 기록하는 `ended_at`
>
> 근거: `spec.md` F7-01~05 · `api-contract.md` §3-3 · PRD FR-050~054

> **이 Phase는 늦어도 된다.** 배치가 과거 턴을 다시 읽으므로, 나중에 만들어도 그 전에 쌓인 로그가 전부 집계된다 — `roadmap.md`. 대신 **판정 로직은 절대 타협하지 않는다**(4-3).

## 4-1. 배치 트리거 (F7-01)

- [ ] Phase 1의 스케줄러에 태운다 — **F2-06 정리·헬스체크와 같은 스케줄러**
- [ ] 매 주기 스캔

```sql
select id from voice_session
 where ended_at is not null
   and pattern_processed_at is null
```

- [ ] 처리 성공 시에만 `pattern_processed_at = now()` 기록
- [ ] **배치 실패가 대화·조회 기능에 영향을 주지 않는다** (F7-01 수용 기준) — 예외를 삼키고 다음 세션으로 넘어간다

> **왜 인메모리 큐(`@Async`)가 아닌가** — Render는 15분 무트래픽에 슬립하고 재배포도 잦다. 인메모리 큐는 그때 증발하고, **그 세션은 관찰이 영영 안 생기는데 아무도 모른다.** 컬럼 방식은 다음 주기에 자동으로 주워간다. F2-06이 "끊긴 세션"을 막으려고 만든 장치인데 같은 사고가 배치에서 반복되면 의미가 없다.

> 실패 시 `pattern_processed_at`이 NULL로 남아 **자동 재시도**된다. 별도 재시도 카운터를 두지 않는다 — 같은 세션이 계속 실패하면 `ops_error_log`에 반복해서 남으므로 그것으로 알아챈다.

## 4-2. 태그별 집계 (F7-02)

- [ ] 사용자 **전체 기간**의 태그별 집계 (이번 세션만이 아니다)
- [ ] 태그별 `occurrences`(등장 턴 수), `tagAvgGap`(그 태그 턴들의 평균 갭)
- [ ] `userAvgGap` — 그 사용자 전체 턴의 평균 갭
- [ ] `ratio = tagAvgGap / userAvgGap`
- [ ] **갭이 `NULL`인 턴은 전부 제외** — 분모·분자 양쪽에서

> `user_baseline.avg_gap`(Phase 3)과 여기서 계산하는 `userAvgGap`은 **같은 값이어야 한다.** 한쪽만 갱신되면 관찰의 `evidence` 숫자와 트렌드 화면이 어긋난다. **`user_baseline`을 읽어 쓰고 여기서 다시 계산하지 않는다.**

## 4-3. 규칙 판정 (F7-03) — **코드가 판정한다**

- [ ] `occurrences >= 3` **AND** `tagAvgGap >= userAvgGap × 1.5`
- [ ] **미달이면 아무 관찰도 만들지 않는다.** 억지로 통찰을 생성하지 않는다

> **여기에 LLM 호출을 섞지 않는다** — 백엔드 절대 원칙 1번, FR-051·052. LLM에 로그를 통째로 주면 그럴듯한 패턴을 **반드시** 만들어낸다. 판정을 규칙으로 고정해야 모든 관찰이 숫자로 역추적된다.
>
> **매일 통찰을 뱉는 앱은 신뢰를 잃는다 — 침묵할 수 있어야 말할 때 믿긴다.** 데이터가 부족한 사용자에게 관찰이 안 생기는 것은 버그가 아니라 사양이다(TC-16).

## 4-4. 관찰 문장 생성 (F7-04) — `POST /internal/observations`

- [ ] 판정을 **통과한 것만** AI서버에 보낸다 — 계약 §3-3
- [ ] 요청은 **숫자와 태그만**: `{ tag, occurrences, tagAvgGap, userAvgGap, ratio }`
- [ ] 응답 `{ sentence }`를 `observation.sentence`에 저장
- [ ] **실패하면 관찰을 만들지 않는다.** 템플릿 문장으로 대체하지 않는다

> **원본 대화를 보내지 않는다**(계약 §3-3). LLM은 표현만 담당하고 패턴의 존재·강도를 판정하지 않는다(FR-054).
> **템플릿 폴백을 두지 않는 이유** — 표현이 어색한 것보다 **근거 없는 문장이 나가는 쪽이 위험**하다. 실패하면 다음 주기에 다시 시도된다(4-1).

## 4-5. evidence 부착 (F7-05)

- [ ] `observation`에 집계 숫자 4개를 그대로 저장 — `occurrences`·`tag_avg_gap`·`user_avg_gap`·`ratio`
- [ ] 근거 turn을 `observation_evidence`에 연결
- [ ] **API 응답의 `evidence` 객체에는 turn ID를 넣지 않는다**(계약 §2-6). 근거 대화는 F7-07 상세 조회의 `turns` 배열로만 내려간다

> **관찰 문장 ↔ evidence 숫자 불일치는 0건이어야 한다**(§1.4 핵심 지표). AI가 돌려준 문장의 숫자를 다시 파싱해 검증하지 않는다 — 애초에 **우리가 보낸 숫자를 그대로 저장**하므로 불일치가 생길 경로가 없다. 문장이 숫자를 왜곡했다면 그건 프롬프트 문제이고 AI 쪽에서 잡는다.

## 완료 기준

- 세션 종료 후 다음 스케줄러 주기에 배치가 돈다
- 조건을 넘긴 태그에만 관찰이 생기고, `observation_evidence`에 근거 turn이 연결된다
- **TC-16** — 태그가 2회만 등장한 사용자에게 **관찰이 생성되지 않는다**
- **TC-17** — 관찰의 `evidence` 숫자와 실제 근거 대화 건수가 일치한다
- 배치가 실패해도 `POST /api/session/start`·조회 API가 정상 동작한다
- 서버를 재시작해도 미처리 세션이 다음 주기에 처리된다
- `api-spec.md`에서 `/internal/observations`를 `구현 완료`로 갱신했다

## 이 Phase에서 하지 않는 것

- **관찰 조회 API** (`GET /api/observations`) — Phase 5
- **관찰 피드백** (F7-08) — Phase 5
- **연쇄 무효화** (F10-02) — Phase 6. 여기서는 생성만 한다
- **`recentObservations` 연결** — Phase 2의 `/internal/sessions` 응답에 이제 실제 값이 들어간다. 그 코드는 Phase 2에 이미 있으므로 **동작 확인만** 한다
