# 회신 — `humeConfigId` 필드 추가 요청

- 원본 요청: [`../../request/backend/hume-config-id.md`](../../request/backend/hume-config-id.md) (앱 → 백엔드, 2026-09-03)
- 회신자: 백엔드
- 회신일: 2026-09-03
- 반영된 계약: [`../../02-architecture/api-contract.md`](../../02-architecture/api-contract.md) v1.3

---

## 결론

**전부 동의합니다.** 4번(발급 실패 처리)만 제안과 다르게 갔습니다.

| 결정 요청 | 답 |
| --- | --- |
| 1. 필드 추가 동의 | **동의** |
| 2. 필드명 `humeConfigId` | **그대로** |
| 3. `resume` 응답 포함 여부 | **포함.** 재연결도 같은 Config로 붙어야 CLM이 이어집니다 |
| 4. 발급 실패 처리 | **503 `HUME_TOKEN_ISSUE_FAILED`로 묶지 않습니다.** 아래 참조 |
| 5. Config 소유자 | **AI 담당이 생성·소유** — 이미 `response/app/clm-turn-pipeline-review.md`와 `request/backend/session-context-lookup.md`에서 그쪽이 그렇게 답해둔 걸 확인했습니다. 발급된 `config_id`를 백엔드가 환경변수로 받아 그대로 내려줍니다 |

## 4번이 제안과 다른 이유

`humeConfigId`의 출처는 요청 문서에도 이미 "백엔드 환경변수"라고 적혀 있습니다. 환경변수에서 읽는 값은 **런타임에 발급되는 게 아니라서 "발급 실패"가 없습니다.** `humeAccessToken`은 매 세션 Hume API를 호출해 받아오니 503이 맞지만, `humeConfigId`는 성격이 다릅니다.

이걸 503으로 묶으면 **환경변수 설정 누락이 마치 Hume 장애처럼 보입니다** — 서버는 멀쩡히 떠 있는데 모든 세션 시작이 실패하고, 원인 추적이 "Hume이 왜 이러지"에서 시작해 한참 돌아 설정 파일에 도착하게 됩니다.

대신 **기동 시 fail-fast**로 갑니다. `HUME_CONFIG_ID` 환경변수가 없으면 서버가 뜨지 않습니다. 런타임에는 항상 값이 있으므로 `humeConfigId`는 **null이 될 수 없고**, 계약에도 그렇게 명시했습니다. 새 에러 코드는 필요 없습니다.

## 함께 알려주신 것 — Hume 요금 확인

Free 티어 월 5분·추가 사용료 $0.06/분(PRD 표기 $0.07/분과 차이) 지적 확인했습니다. PRD §14-3 백엔드 과제로, **9/10 도그푸딩 전에 결제·플랜을 실측**하겠습니다. `custom_session_id`를 앱이 붙이는 부분은 계약 변경이 필요 없다는 판단에 동의합니다.

## 반영한 문서

| 문서 | 변경 |
| --- | --- |
| `02-architecture/api-contract.md` | v1.3 — §2-4·§2-5-1에 `humeConfigId` 추가(null 불가, fail-fast), §6 변경 이력 |
| `00-context/spec.md` | v1.1 — F2-01 출력에 `humeConfigId`·`livePollIntervalSec` 반영 완료 |
