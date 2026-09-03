# 회신 — 세션 요약 생성 경로 요청

- 원본 요청: [`../../request/backend/session-summary-endpoint.md`](../../request/backend/session-summary-endpoint.md) (AI → 백엔드, 2026-09-03)
- 회신자: 백엔드
- 회신일: 2026-09-03
- 반영된 계약: [`../../02-architecture/api-contract.md`](../../02-architecture/api-contract.md) v1.3 §3-5

---

## 결론

**제안하신 동기 호출 방식 그대로 채택합니다.** 호출 조건 하나만 추가했습니다.

| 결정 요청 | 답 |
| --- | --- |
| 1. 신설 방식 | **`POST /internal/summaries` 동기 호출.** 대안(비동기 PATCH)은 채택하지 않았습니다 — 아래 참조 |
| 2. 경로·필드명 | 제안하신 그대로 (`sessionId`, `turns[].role/transcript` → `summary`) |
| 3. 타임아웃 | **3초, 제안대로** |

## 동기를 택한 이유

spec F2-05의 수용 기준이 "종료 후 S02-1에 요약이 표시되고"입니다. 비동기(PATCH) 방식을 쓰면 대안 설명에도 있듯 **S02-1이 요약 없이 뜨고 S05 목록에서만 보이게** 되어, 그 화면이 만들어진 이유 자체가 없어집니다. 3초 대기는 NFR-01(대화 중 응답 지연 p95 2초)과 무관합니다 — 이건 대화가 끝난 뒤의 처리라 임계 경로 밖입니다.

## 추가한 조건 — `endReason: "timeout"`은 호출하지 않습니다

세션 종료는 사용자만 부르는 게 아니라 **F2-06 스케줄러(미종료 세션 정리)도 부릅니다.** 밀린 세션을 여러 건 정리할 때 건당 3초씩 기다리면 스케줄러가 느려지고, 그 세션들은 애초에 아무도 보고 있지 않습니다. 그래서 `endReason`이 `user_end`·`soft_wrap`·`hard_cut`일 때만 이 엔드포인트를 호출하고, `timeout`이면 호출 없이 `summary: null`로 닫습니다. §2-5에 각주로 명시했습니다.

## 반영한 문서

| 문서 | 변경 |
| --- | --- |
| `02-architecture/api-contract.md` | v1.3 — §2-5 요약 생성 각주(동기 3초, timeout 제외), §3-5 신설, §6 변경 이력 |
| `00-context/spec.md` | v1.1 — F2-05 처리 ④ 반영 완료 |
| `ai-server/prompts/summary.system.md` | 프롬프트 작성은 AI 쪽에서 진행 부탁드립니다 |
