# AI Request

AI 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- 모델/프롬프트 관련 요청, valence·갭 계산 변경, CLM 응답 포맷 조정, 평가 세트 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `valence-mapping-table.md`, `crisis-keyword-list.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 막고 있던 작업 |
| --- | --- | --- |
| [env-example-drift.md](env-example-drift.md) | ⏳ **회신 대기** (2026-09-05) | **위기 응답 109 안내(F4)와 관찰 생성.** `.env.example` 세 줄이 `config.py`보다 낡아, 회신이 안내한 대로 복사하면 **`AI_RESPOND_EFFORT=low`(109가 잘린다)와 `AI_MODEL_OBSERVE=gemini-2.5-pro`(404)가 되살아난다.** 덧붙임으로 **cron 서비스(`cron-job.org`)** 와 **Config 5건 중 CLM만 배포에 묶여 있다는 것**도 함께 적었다 |
| [deploy-handoff.md](deploy-handoff.md) | ✅ **회신 완료** (2026-09-05) | ~~배포 주소·새 시크릿·슬립 대 fail-closed 판단~~ → **cron이 맞다**(복귀 60초를 타임아웃으로 덮으면 Hume이 먼저 끊는다). ⚠️ **cron이 두 곳을 찔러야 한다** — AI서버도 Cloud Run 무료라 잠든다. AI서버는 **Cloud Run 배포**로 가고 주소가 나오면 준다. 회신 `../../response/backend/deploy-handoff.md` |
| [gemini-switch-mismatch.md](gemini-switch-mismatch.md) | ✅ **회신 완료** (2026-09-05) | ~~Gemini 키는 넣었는데 모델명이 Claude 그대로~~ → **보고 있던 `.env`가 로컬 낡은 파일**이었다. `.env.example`이 단일 출처다. ⚠️ **회신이 알려준 `gemini-2.5-pro` 404**(신규 사용자 미제공)가 실측으로 나왔다. 타임아웃 **3000ms**. **다만 `.env.example`이 아직 안 맞는다 → [env-example-drift.md](env-example-drift.md)** |
| [hume-config-setup.md](hume-config-setup.md) | ✅ **회신 완료** (2026-09-05) | ~~Config의 `language_model`이 `null`이라 CLM이 안 붙어 있다~~ → **등록이 막힌 게 아니라 넣을 주소가 없었다.** AI서버를 **Cloud Run에 배포**하고 그 주소를 넣는다(터널 아님). 비활성 **120 → 420초**. **`HUME_CONFIG_ID`는 그대로** `23d6162d-…`. 회신 `../../response/backend/hume-config-setup.md` |
| [latency-diagnosis.md](latency-diagnosis.md) | ✅ **회신 완료** (2026-09-05) | ~~분석에 `reasoning_effort` 누락 · SDK 재시도가 429를 지연으로 가린다~~ → **재측정 결과 합계 p95가 12.5초가 아니라 3.19초**(3.9배 과장). ②③이 원인이었고 ①은 아니었다(안 붙인 상태로 이미 1초). **유료 전환을 서두를 이유가 없어졌다.** 회신 `../../response/backend/latency-diagnosis.md` |
| [integration-round-1.md](integration-round-1.md) | ✅ **회신 완료** (2026-09-05) | ~~통합 1·2차에서 결함 2건 — fail-closed 경로 500, 로그에 `sessionId` 평문~~ → 500은 선제 수정 완료(`43c97be`), `sessionId`는 `sessionRef` 해시로 교체. 회신 `../../response/backend/integration-round-1.md` |
| [hume-account-setup.md](hume-account-setup.md) | ✅ **회신 완료** (2026-09-05) | ~~Hume 계정 소유·결제 주체, 콘솔 실측 4건, 공유 시크릿 전달 경로~~ → 계정 소유 수락, **Creator 권장**(490분에서 Starter보다 싸다), 실측은 가입 후. 회신 `../../response/backend/hume-account-setup.md` |
| [integration-test-path.md](integration-test-path.md) | ✅ **회신 완료** (2026-09-04) | ~~AI서버 → 백엔드 방향에 도달 경로가 없다(양쪽 로컬)~~ → 양쪽 터널 동의, **AI서버 준비 목표 9/6**, `GET /internal/sessions` 먼저. 회신 `../../response/backend/integration-test-path.md` |
| [turn-index-numbering.md](turn-index-numbering.md) | ✅ **회신 완료** (2026-09-04) | ~~이어하기 후 `turnIndex` 리셋 시 턴이 조용히 유실~~ → 캐시 시드 + 유휴 재조회로 리셋 경로 제거, `occurredAt` 규칙을 **계약 v1.5**에 명시. 회신 `../../response/backend/turn-index-numbering.md` |
| [clm-turn-pipeline-review.md](clm-turn-pipeline-review.md) | ✅ **회신 완료** (2026-09-03) | ~~PRD §9.1 실시간 턴 처리 — 순환 의존 + 채널 독립성~~ → 분석 호출 분리·프로소디 미노출(FR-025)로 해소. 회신 `../../response/app/clm-turn-pipeline-review.md`, 설계 `../../02-architecture/ai-pipeline.md` |
