# Phase 1 — 골격 · 인증

의존 없음. 가장 먼저 착수 가능.

## 체크리스트

- [ ] Spring Boot 프로젝트 골격 — 빌드 도구·베이스 패키지는 `README.md` "스택" 표가 미확정이면 여기서 정하고 그 표부터 갱신한다
- [ ] Supabase(PostgreSQL) 연결 설정
- [ ] `GET /api/health` — DB 연결 확인 포함, Supabase 유휴 방지용 주기 요청에도 재사용 — 근거: spec F11-02, api-contract §2-12
- [ ] `POST /api/auth/kakao` — 카카오 액세스 토큰 검증 → `account`/`profile`/`account_profile` 생성(신규 시) → JWT 발급 — 근거: spec F1-01, api-contract §2-1
- [ ] JWT 인증 필터 — `Authorization: Bearer <JWT>`, 만료 7일, `/api/auth/kakao`·`/api/health` 제외 전 엔드포인트 필수 — 근거: api-contract §1-1
- [ ] `GET /api/me` — 최소 뼈대(프로필 조회)만. `openSession` 필드는 Phase 2에서 채운다 — 근거: api-contract §2-2
- [ ] 공통 오류 응답 포맷 (`ErrorCode` + `GlobalExceptionHandler`) — 근거: api-contract §1-2
- [ ] `DELETE /api/account` — 라우트만 등록, 실제 삭제 로직은 Phase 6 — 근거: spec F1-04

## 완료 기준

- TC-01 (카카오 로그인 → 로그아웃 → 재로그인 → 동일 `profileId`, 이전 데이터 유지)
- TC-03 (앱 번들·네트워크 응답 어디에도 Hume API 키 없음 — 이 Phase는 해당 없음, Phase 2에서 검증)
- JWT 없이 감정 데이터 API 호출 시 전부 401

## 회신 대기

없음 — 이 Phase를 막는 대기 항목 없음.
