# `.env.example`이 `config.py`보다 낡았습니다 — 복사하면 방금 고친 결함 둘이 되살아납니다

> **상태: ⏳ 회신 대기** (요청 2026-09-05)
> 회신은 `../../response/backend/env-example-drift.md`에 들어옵니다.
> **막고 있는 작업**: **위기 응답의 109 안내(F4)** 와 **관찰 생성.** `gemini-switch-mismatch.md` 회신이 안내한 대로 `.env.example`을 복사하면 그 두 개가 깨진 상태로 시작됩니다.

- 요청자: 백엔드
- 대상: AI
- 관련 문서: `../../response/backend/gemini-switch-mismatch.md` · `ai-server/.env.example` · `ai-server/app/config.py`

---

## 회신대로 했더니 값이 안 맞습니다

회신에서 **"`.env.example`을 다시 복사하시면 됩니다"** 라고 하셨고, 같은 문서에 **"현재 값 (`.env.example` 그대로)"** 로 블록을 적어 주셨습니다. **그 블록과 실제 파일이 세 줄 다릅니다.**

| 변수 | `.env.example` (실제) | `config.py` (코드) | 회신 문서에 적힌 값 |
| --- | --- | --- | --- |
| `AI_MODEL_ANALYZE` | `gemini-3.5-flash-lite` | 〃 | 〃 |
| `AI_MODEL_RESPOND` | `gemini-3.8-flash` | 〃 | 〃 |
| **`AI_RESPOND_EFFORT`** | **`low`** | **`none`** | **`none`** |
| **`AI_MODEL_OBSERVE`** | **`gemini-2.5-pro`** | **`gemini-3.8-flash`** | **`gemini-3.8-flash`** |
| **`AI_OBSERVE_EFFORT`** | **`medium`** | **`none`** | **`none`** |
| `AI_MODEL_SUMMARY` | `gemini-3.5-flash-lite` | 〃 | 〃 |
| `AI_ANALYZE_TIMEOUT_MS` | `3000` | `3000` | `3000` |

**코드는 맞고 회신도 맞습니다. 틀린 건 `.env.example` 세 줄뿐입니다.** `5ccf96c`에서 `AI_ANALYZE_TIMEOUT_MS`와 그 주석은 고쳤는데 위 세 줄이 같이 안 따라갔습니다.

## 왜 이게 그냥 낡은 값이 아닌가 — `.env`가 `config.py`를 덮습니다

`config.py`의 값은 **기본값**이고 `.env`가 있으면 그쪽이 이깁니다. 그래서 `.env.example`을 복사하는 순간 **코드에서 고친 것이 환경변수로 다시 덮입니다.**

### ⛔ 1. `AI_RESPOND_EFFORT=low` — 109 안내가 잘립니다

`config.py`에 그쪽이 직접 적어 두신 주석입니다.

```python
# thinking을 끄지 않으면 사고 토큰이 출력 예산을 먹어 문장이 잘린다(실측).
ai_respond_effort: str = "none"
```

`f3fa9fd` 커밋에서 **"심각했던 것 — 위기 응답에서 109가 잘려 나갔습니다 … 안전 경로가 조용히 깨지는 종류"** 라고 쓰신 그 결함입니다. `.env.example`을 복사하면 **`low`가 들어가 그대로 재현됩니다.**

**위기 안내는 FR-032·033이고 `spec.md` §11이 "F4는 어떤 스코프 컷에서도 자르지 않는다"고 못박은 자리**라, 다른 값들과 등급이 다릅니다.

### ⛔ 2. `AI_MODEL_OBSERVE=gemini-2.5-pro` — 404입니다

회신에서 **직접 "쓰면 안 됩니다"** 라고 하신 그 모델이 `.env.example`에 그대로 남아 있습니다.

> "This model models/gemini-2.5-pro is no longer available to new users."

복사해서 쓰면 **관찰 문장화가 전부 404**로 떨어집니다. 백엔드는 그걸 "문장이 없으면 관찰도 없다"로 정확히 처리하므로(템플릿 폴백 없음) **S03 발견 화면이 조용히 빈 채로 남습니다.** 오류처럼 보이지 않습니다.

## 부탁드리는 것

**`.env.example` 세 줄을 `config.py`와 맞춰 주세요.** 그게 전부입니다.

```
AI_RESPOND_EFFORT=none
AI_MODEL_OBSERVE=gemini-3.8-flash
AI_OBSERVE_EFFORT=none
```

`ai-server/`는 그쪽 폴더라 저희가 고치지 않았습니다.

## 함께 알려드리는 것 (요청 아님)

- **`defects.md`의 모양 ③ "베낀 것이 어긋난다"입니다.** 코드를 고치고 그 값을 복사해 둔 쪽을 안 고친 경우입니다. 그쪽 결함 기록에 이미 있는 모양이라 덧붙일 만합니다
- **저희 로컬 `.env`가 낡았다는 지적은 맞습니다.** 다만 지금 `.env.example`을 복사하면 위 두 결함이 들어오므로, **고쳐 주신 뒤에 복사하겠습니다**
- 이 대조는 기계로 확인할 수 있습니다 — `.env.example`의 `KEY=값`과 `config.py`의 같은 이름 기본값을 맞춰보는 것으로, 저희는 그 방식으로 찾았습니다. **테스트로 걸어 두면 다음에 벤더를 또 바꿀 때 같은 자리를 안 밟습니다** (넣을지는 그쪽 판단입니다)
