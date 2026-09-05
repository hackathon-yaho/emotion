# 백엔드가 배포됐습니다 — **웹을 다시 빌드해야 지금 배포본이 서버를 찾습니다**

> **상태: ⏳ 회신 대기** (요청 2026-09-05)
> 회신은 `../../response/backend/backend-deployed-rebuild.md`에 들어옵니다.
> **막고 있는 작업**: **지금 GitHub Pages에 떠 있는 빌드가 백엔드를 못 찾습니다.** 로그인부터 안 됩니다.

- 요청자: 백엔드
- 대상: 앱
- 관련 문서: `.github/workflows/app-web.yml` · `../../../backend/docs/phase-7-ops-deploy.md`

---

## 백엔드 주소

**`https://emotion-6yeh.onrender.com`**

실동작 확인했습니다 (2026-09-05):

| 확인 | 결과 |
| --- | --- |
| `GET /api/health` | ✅ `{"status":"ok","db":"ok"}` |
| DB (Supabase) | ✅ 11테이블 |
| **CORS 프리플라이트** | ✅ `https://hackathon-yaho.github.io` 오리진에 `access-control-allow-origin` 반환 |

**커스텀 도메인이 붙으면 알려주세요** — `CORS_ALLOWED_ORIGINS`에 추가하면 되고 **백엔드 재배포는 필요 없습니다.**

## ⛔ 지금 떠 있는 빌드가 서버를 못 찾습니다

저장소 변수는 **백엔드가 등록했습니다.** 그런데 **등록 시각이 마지막 빌드보다 늦습니다.**

| | 등록 시각 | 마지막 성공 빌드 |
| --- | --- | --- |
| `API_BASE_URL` | 2026-09-05 05:23 | \ |
| `KAKAO_REST_KEY` | 2026-09-04 20:10 | **2026-09-04 19:38** |

`app-web.yml`이 `--dart-define`으로 빌드 시점에 값을 굽기 때문에, **19:38 빌드에는 둘 다 없습니다.**

```yaml
--dart-define=API_BASE_URL=${{ vars.API_BASE_URL || 'http://localhost:8080' }}
--dart-define=KAKAO_REST_KEY=${{ vars.KAKAO_REST_KEY }}
```

그래서 지금 배포본은 —

- **`API_BASE_URL`이 폴백 `http://localhost:8080`으로 구워져 있습니다.** 사용자 브라우저의 localhost를 부르므로 **모든 API 호출이 실패**합니다
- **`KAKAO_REST_KEY`가 빈 문자열입니다.** 로그인 인가 URL의 `client_id`가 비어 나갑니다

**둘 다 코드 문제가 아니라 빌드 시점 문제입니다.** 값은 이미 저장소에 있습니다.

## 부탁드리는 것 — 다시 빌드만 해주세요

`app-web.yml`은 **`app/**` 가 바뀔 때만** 돕니다. 백엔드가 문서만 푸시해서는 안 걸립니다.

**`workflow_dispatch`가 열려 있으니 수동 실행이면 됩니다.**

```sh
gh workflow run app-web.yml --repo hackathon-yaho/emotion
```

또는 Actions 탭 → `app-web` → Run workflow.

> **백엔드가 대신 돌려도 되지만 그쪽 배포라 손대지 않았습니다.** 원하시면 말씀해 주세요.

## 빌드 후 확인해 주시면 좋은 것

1. **로그인이 끝까지 가는지** — 카카오 인가 → `POST /api/auth/kakao` → JWT. 백엔드 쪽 `redirectUri` 등록 목록은 `https://hackathon-yaho.github.io/emotion/`·`http://localhost:3000/` 입니다
2. **`GET /api/me`가 200인지** — 여기까지 오면 CORS·JWT·DB가 전부 확인됩니다
3. **대화 시작은 아직 안 됩니다** — `POST /api/session/start`는 201로 실물 Hume 토큰을 내지만, **Hume Config에 CLM이 안 붙어 있어**(`../ai/hume-config-setup.md` ⏳) 대화 내용이 우리 파이프라인을 안 탑니다. 갭·되묻기·기록이 비어 있어도 앱 문제가 아닙니다

## 함께 알려드리는 것 (요청 아님)

- **첫 요청이 느릴 수 있습니다.** Render 무료는 15분 유휴에 잠들고 복귀에 **약 1분**이 걸립니다. cron 킵얼라이브를 걸면 사라지는데 **아직 안 걸었습니다** — 그때까지는 첫 호출에 타임아웃을 넉넉히 잡아 주세요
- 대기열(계약 §2-14)은 **서버에서 꺼져 있습니다.** `202` 응답은 지금 나오지 않습니다
