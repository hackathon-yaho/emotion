# 백엔드 Request

백엔드 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- API 신규/수정 요청, 데이터 모델 변경, 서버 로직 관련 요청 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `session-resume-contract.md`, `turn-log-schema-update.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 막고 있는 작업 |
| --- | --- | --- |
| [hume-config-id.md](hume-config-id.md) | ⏳ **회신 대기** (2026-09-03) | EVI handshake에 필요한 `config_id`가 계약에 없음. CLM 전환 시점부터 **F2-02 EVI 연결**이 막힘 (기본 LLM 연결·화면 개발은 진행 가능) |
| [live-turn-signal.md](live-turn-signal.md) | ⏳ **회신 대기** (2026-09-03) | 대화 중 턴 신호(위기 감지·갭·valence)를 앱이 읽을 경로가 계약에 없음. **S07 위기 안내 트리거**(F4-04 앱 측)와 **S02 데모 모드 수치 노출**(F11-01 앱 측) 연결 보류. UI는 목업 트리거로 선행 |
| [session-context-lookup.md](session-context-lookup.md) | ⏳ **회신 대기** (2026-09-03, 요청자 AI) | AI서버가 세션 임계값·모드·시작 시각을 알 경로가 계약에 없음. `/internal/turns`의 `thresholdMode` 정확성, F2-03 마무리 유도, **CLM 인증**(`custom_session_id` 검증 + sessionId 엔트로피). 회신 전에는 `.env` 고정 임계값으로 진행 |
| [session-summary-endpoint.md](session-summary-endpoint.md) | ⏳ **회신 대기** (2026-09-03, 요청자 AI) | F2-05 `summary` 생성 경로가 계약에 없음. `POST /internal/summaries` 제안. 계약이 null을 허용하므로 다른 작업은 막히지 않음 |
