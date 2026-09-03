# backend — Java / Spring Boot · Supabase

담당: **백엔드**(팀장).

- 카카오 인증·JWT, 세션 생성·Hume 단기 토큰 발급, 턴 로그 적재, 패턴 배치(F7), 대시보드 API, 삭제·탈퇴, 미종료 세션 정리 스케줄러(F2-06)
- 공개 API·내부 API 계약: [`../docs/02-architecture/api-contract.md`](../docs/02-architecture/api-contract.md)
- 데이터 모델: [`../docs/00-context/prd.md`](../docs/00-context/prd.md) §7 · [`spec.md`](../docs/00-context/spec.md) §6
- **로그·오류·`crisis_event`에 발화 내용을 남기지 않는다** (FR-092)

이 폴더에 대한 요청은 `../docs/request/backend/`, 백엔드가 보낸 요청의 회신은 `../docs/response/backend/`.
