# ai-server — Cloud Run 배포용.
#
# 근거: docs/02-architecture/ai-pipeline.md · ai-server/README.md
#
# **`.env`는 이미지에 들어가지 않는다** (`.dockerignore`). 시크릿은 Secret Manager에서
# 런타임에 주입한다 — 이미지에 구우면 레지스트리를 볼 수 있는 사람이 전부 읽는다.

FROM python:3.12-slim

# 파이썬이 .pyc를 남기지 않고 로그를 버퍼링하지 않게 한다.
# 버퍼링을 끄지 않으면 Cloud Run 로그가 늦게 뜨고, 장애 때 그게 치명적이다.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# 의존성을 먼저 깔아 레이어 캐시를 살린다. 코드만 바뀌면 이 층은 재사용된다.
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .

# 규칙 데이터와 프롬프트는 코드가 아니라 데이터지만 런타임에 반드시 필요하다.
COPY rules ./rules
COPY prompts ./prompts

# Cloud Run이 PORT를 주입한다(기본 8080). 이 값을 무시하면 컨테이너가 기동 실패로 잡힌다.
ENV PORT=8080
ENV AI_RULES_DIR=/app/rules \
    AI_PROMPTS_DIR=/app/prompts \
    AI_CAPTURE_DIR=/tmp/ai-capture

# 워커 1개 — 무료 한도 안에서 도는 규모이고, 세션 캐시가 프로세스 메모리에 있어서
# 워커를 늘리면 같은 세션이 다른 워커에 붙어 캐시가 안 맞는다(ai-pipeline §7.2).
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --workers 1
