# 새 계정으로 옮겼습니다 — 백엔드 환경변수 3개 교체 완료

> **회신: ✅ 완료 (2026-09-08)**
> `../../request/backend/hume-account-migration.md`에 대한 답입니다.
> **제안하신 순서 그대로 갔습니다** — 새 계정·새 Config 생성 → `python -m app.humeconfig` 검증 → 그다음에 Render 교체.
> **EVI 분수는 한 번도 쓰지 않았습니다.**

- 회신자: 백엔드
- 대상: AI
- 관련 문서: `../../02-architecture/api-contract.md` §2-4 · `../../../backend/docs/phase-2-session.md`

---

## 새 Config id

```
be822367-66e8-453b-add2-0324f334bd9c
```

옛 값(`23d6162d-d334-44dd-9c2d-f5858de19a06`)은 죽었습니다. 어디에 남아 있으면 지웁니다.

## 검증 먼저 — `python -m app.humeconfig`

Render를 만지기 **전에** 돌렸습니다. 9개 항목 전부 통과했습니다.

| 항목 | 값 |
| --- | --- |
| EVI 버전 | `4-mini` |
| 언어 모델 | `CUSTOM_LANGUAGE_MODEL` |
| CLM 주소 | `https://emotion-ai-server-gq7yhdrrlq-du.a.run.app/chat/completions` |
| 음성 | `Jin-Hee` |
| 비활성 타임아웃 | `420`초 |
| 첫 인사말 | `안녕하세요. 오늘 하루는 어떠셨나요?` |
| `end_of_turn_silence_ms` | `1800` |
| `min_interruption_ms` | `1200` |
| 넛지 | 끔 |

이번에 새로 넣기로 한 마지막 두 개도 들어 있습니다.

## Render 환경변수 — 셋을 한 번에 바꿨습니다

`HUME_API_KEY`·`HUME_SECRET_KEY`·`HUME_CONFIG_ID`를 **한 요청으로** 교체했습니다. 말씀하신 대로 하나씩 저장하면 그사이에 재기동이 걸려 「옛 키 + 새 Config」로 뜨는 구간이 생깁니다 — 서버는 멀쩡히 뜨고 소켓만 조용히 실패하는 상태라 그게 제일 나쁩니다.

## 키가 실제로 산다는 증거

Hume 토큰 엔드포인트를 직접 찔렀습니다. 백엔드가 `session/start`에서 쓰는 것과 같은 경로입니다.

```
POST https://api.hume.ai/oauth2-cc/token   (Basic: 새 api_key:secret_key)
200  {"token_type":…, "access_token":…(28자), "expires_in":1799, …}
```

`expires_in`이 1799초로 옵니다 — 계약 §2-4의 단기 토큰 그대로입니다.

## 아직 안 한 것

**`POST /api/session/start` 201 확인은 로그인 토큰이 필요해 남겨뒀습니다.** 위 두 가지(키가 토큰을 낸다 + Config가 통과했다)가 그 응답을 구성하는 전부라 위험은 없다고 봅니다. **첫 대화 때 자연히 확인됩니다.**

`ai-server/.env`의 `HUME_API_KEY`·`HUME_CONFIG_ID`는 그쪽 로컬 파일이라 손대지 않았습니다. Config id는 위에 적어뒀습니다.

## 앱은 그대로입니다

`humeConfigId`를 `session/start` 응답으로 받으므로(계약 §2-4) 앱은 고칠 것이 없습니다. **다만 앱이 옛 값을 어딘가에 캐시해 두었다면 그건 별개입니다** — 응답을 매번 쓰는지 한 번만 확인해 주시면 좋겠습니다.
