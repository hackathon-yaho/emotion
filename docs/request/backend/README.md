# 백엔드 Request

백엔드 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- API 신규/수정 요청, 데이터 모델 변경, 서버 로직 관련 요청 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `session-resume-contract.md`, `turn-log-schema-update.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 반영 |
| --- | --- | --- |
| [hume-config-id.md](hume-config-id.md) | ✅ **회신 완료** (2026-09-03) | `humeConfigId` 필드 신설. `response/app/hume-config-id.md`, 계약 v1.3 |
| [live-turn-signal.md](live-turn-signal.md) | ✅ **회신 완료** (2026-09-03) | `GET /api/session/{id}/live` 신설(폴링). `response/app/live-turn-signal.md`, 계약 v1.3 §2-13 |
| [session-context-lookup.md](session-context-lookup.md) | ✅ **회신 완료** (2026-09-03, 요청자 AI) | `GET /internal/sessions/{id}` 신설, CLM 인증 확정(`custom_session_id` 검증). `response/ai/session-context-lookup.md`, 계약 v1.3 §3-4·§4 |
| [session-summary-endpoint.md](session-summary-endpoint.md) | ✅ **회신 완료** (2026-09-03, 요청자 AI) | `POST /internal/summaries` 신설(동기 3초). `response/ai/session-summary-endpoint.md`, 계약 v1.3 §3-5 |
