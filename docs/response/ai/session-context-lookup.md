# 회신 — 세션 컨텍스트 내부 조회 엔드포인트 요청

- 원본 요청: [`../../request/backend/session-context-lookup.md`](../../request/backend/session-context-lookup.md) (AI → 백엔드, 2026-09-03)
- 회신자: 백엔드
- 회신일: 2026-09-03
- 반영된 계약: [`../../02-architecture/api-contract.md`](../../02-architecture/api-contract.md) v1.3 §3-4·§4

---

## 결론

**전부 동의합니다.**

| 결정 요청 | 답 |
| --- | --- |
| 1. 엔드포인트 신설 · 전달 수단 | **동의, `GET`.** push 방식은 채택하지 않았습니다 — 조회 시점을 AI서버가 통제하는 편이 캐시 정책과 맞습니다 |
| 2. 경로·필드명 | `GET /internal/sessions/{sessionId}`, 제안하신 필드 그대로(`status`·`startedAt`·`usedSec`·`thresholdMode`·`gapThreshold`·`softWrapSec`·`hardCutSec`·`demoMode`·`recentObservations`) |
| 3. `sessionId` 엔트로피 | **UUIDv4(접두사 없음, 122비트)로 올렸습니다.** 계약 전체 예시를 교체했습니다(§1-1에 로깅 금지 규칙도 추가) |
| 4. `recentObservations` 포함 | **포함.** F8을 실제로 만들 때 계약을 또 고치는 왕복을 아끼는 쪽이 낫다고 판단했습니다 |
| 5. 데모 세션 재시도 강화 | **AI서버 몫이 맞습니다.** `live-turn-signal.md` 회신 참조 — 다만 데모 전용이 아니라 `/internal/turns` 재시도를 **전체 1회 → 3회**로 올렸습니다 |

## CLM 인증 — `custom_session_id` 검증으로 확정합니다

제안하신 대로, `language_model_api_key`(앱이 들어야 해서 웹 번들에 노출)는 쓰지 않고 **이 조회로 CLM 인증을 겸합니다.** `status: "ended"`도 이 엔드포인트는 200으로 돌려드리니, **401로 바꾸는 판단은 AI서버 쪽에서** 해주세요(§4에 그렇게 적었습니다).

**조회 실패 시 처리를 제안과 다르게 갔습니다.** 요청하신 "`.env` 고정 임계값으로 인증 통과"는 fail-open인데, 1번을 채택한 지금 이건 "백엔드 장애 시간 = 인증 무방비 시간"이 됩니다. 대신:

- **캐시 히트는 백엔드 상태와 무관하게 통과**합니다 (세션당 1회 조회 + `hardCutSec + 30분` TTL 캐시라는 제안을 그대로 살렸습니다).
- **캐시 미스 + 조회 실패(5xx·타임아웃)는 401로 fail-closed**로 갑니다.

fail-closed로 잃는 게 없다고 판단한 근거는, 백엔드가 죽어 있으면 `POST /api/session/start`도 죽어 있어 **새 세션 자체가 생기지 않기 때문**입니다. 진행 중인 대화는 캐시가 지키므로 F5-04(백엔드 다운에도 대화 계속)의 목적은 이미 달성됩니다.

## Hume 콘솔 Config

"AI 담당이 생성·소유"하시겠다는 부분, `hume-config-id.md` 회신에 그대로 반영해 확인했습니다. 발급된 `config_id`는 백엔드가 환경변수로 받아 `session/start`·`resume` 응답에 그대로 내려드립니다.

## 반영한 문서

| 문서 | 변경 |
| --- | --- |
| `02-architecture/api-contract.md` | v1.3 — §1-1 `sessionId` 규칙, §3-4 신설, §4 CLM 인증 확정, §6 변경 이력 |
| `02-architecture/ai-pipeline.md` | §7 확정값 반영은 AI 쪽에서 진행 부탁드립니다 |
| `00-context/spec.md` | v1.1 — F2-01(`sessionId` 생성 규칙)·F2-03(경과 판단 주체) 반영 완료 |
