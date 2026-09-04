# ai-server — 실행 명령 단일 출처. README의 명령과 여기가 다르면 여기가 맞다.
# 근거: ai-server/README.md, docs/02-architecture/ai-pipeline.md §11

PY ?= uv run

.PHONY: help install test lint run eval clean

help:
	@echo "make install  의존성 설치 (uv sync --extra dev)"
	@echo "make test     단위 테스트 — rules/ 전부 + 경계 검사"
	@echo "make lint     ruff"
	@echo "make run      개발 서버 (포트 8100, reload)"
	@echo "make eval     평가 세트 → eval/reports/"

install:
	uv sync --extra dev

test:
	$(PY) pytest -q

lint:
	$(PY) ruff check app tests
	$(PY) ruff format --check app tests

run:
	$(PY) uvicorn app.main:app --port 8100 --reload

eval:
	$(PY) python eval/run_eval.py

clean:
	rm -rf .pytest_cache .ruff_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
