FROM python:3.14-slim AS build

COPY --from=ghcr.io/astral-sh/uv:0.11.24 /uv /uvx /bin/

WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY src/ ./src/
RUN uv sync --frozen --no-dev --no-editable


FROM python:3.14-slim AS runtime

ARG GIT_SHA=unknown
ARG VERSION=0.1.0

LABEL org.opencontainers.image.source="https://github.com/Demosz/rick_project" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${VERSION}"

ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:${PATH}"

WORKDIR /app

RUN useradd --uid 10001 --create-home app

COPY --from=build /app/.venv /app/.venv

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz', timeout=2).read()"

CMD ["gunicorn", "web.app:app", "--bind", "0.0.0.0:8080", "--workers", "2"]
