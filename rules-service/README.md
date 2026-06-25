# rules-service

FastAPI backend serving MTG comprehensive rules data. Parsed once from `data/MagicCompRules.txt` at process start; in-memory thereafter.

## Run locally

```bash
cd rules-service
uv sync
uv run uvicorn rules_service.main:app --reload --port 8001
```

`rules-service` has no upstream dependencies — start it first; the [web](../web/README.md) frontend will reach it at `http://localhost:8001`.

## Endpoints

- `GET /rule/random` — random `{"id": "...", "text": "..."}`.
- `GET /rule/{rule_id}` — the rule with that id, or 404 `{"detail": "Rule not found"}`.
- `GET /healthz` — `{"status": "ok"}`.
- `GET /docs` — Swagger UI. `GET /openapi.json` — raw spec.
