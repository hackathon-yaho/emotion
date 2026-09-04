# AI Request

AI 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- 모델/프롬프트 관련 요청, valence·갭 계산 변경, CLM 응답 포맷 조정, 평가 세트 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `valence-mapping-table.md`, `crisis-keyword-list.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 막고 있던 작업 |
| --- | --- | --- |
| [hume-account-setup.md](hume-account-setup.md) | ✅ **회신 완료** (2026-09-05) | ~~Hume 계정 소유·결제 주체, 콘솔 실측 4건, 공유 시크릿 전달 경로~~ → 계정 소유 수락, **Creator 권장**(490분에서 Starter보다 싸다), 실측은 가입 후. 회신 `../../response/backend/hume-account-setup.md` |
| [integration-test-path.md](integration-test-path.md) | ✅ **회신 완료** (2026-09-04) | ~~AI서버 → 백엔드 방향에 도달 경로가 없다(양쪽 로컬)~~ → 양쪽 터널 동의, **AI서버 준비 목표 9/6**, `GET /internal/sessions` 먼저. 회신 `../../response/backend/integration-test-path.md` |
| [turn-index-numbering.md](turn-index-numbering.md) | ✅ **회신 완료** (2026-09-04) | ~~이어하기 후 `turnIndex` 리셋 시 턴이 조용히 유실~~ → 캐시 시드 + 유휴 재조회로 리셋 경로 제거, `occurredAt` 규칙을 **계약 v1.5**에 명시. 회신 `../../response/backend/turn-index-numbering.md` |
| [clm-turn-pipeline-review.md](clm-turn-pipeline-review.md) | ✅ **회신 완료** (2026-09-03) | ~~PRD §9.1 실시간 턴 처리 — 순환 의존 + 채널 독립성~~ → 분석 호출 분리·프로소디 미노출(FR-025)로 해소. 회신 `../../response/app/clm-turn-pipeline-review.md`, 설계 `../../02-architecture/ai-pipeline.md` |
