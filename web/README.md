# web

Flask frontend for the MTG rules demo. Renders a random rule per page load by HTTP-calling the [rules-service](../rules-service/README.md) backend.

## Run locally

```bash
cd web
uv sync
uv run flask --app web.app run --debug --port 5000
```

Open <http://localhost:5000/>.

`web` depends on `rules-service` being reachable. Start it first (see [rules-service/README.md](../rules-service/README.md)); the default upstream URL is `http://localhost:8001`, overridable via the `RULES_SERVICE_URL` environment variable:

```bash
RULES_SERVICE_URL=http://localhost:9001 uv run flask --app web.app run --debug --port 5000
```

If `rules-service` is unreachable or slow (>2 s), `/` returns a 502 with a friendly fallback page instead of a 500.

## Endpoints

- `GET /` — HTML page with a random rule fetched from `rules-service/rule/random`. 502 + fallback page on upstream failure.
- `GET /healthz` — `{"status": "ok"}`. Used by container/K8s probes; no upstream check.
