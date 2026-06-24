# rick-project - MTG rules on EKS

Two web services deployed on AWS EKS with image signing, automated security scanning, and a service mesh. The web frontend in Flask, and the backend is FastAPI.

## Architecture

- **`web/`** — Flask + gunicorn frontend. Renders a random Magic: The Gathering rule on each request.
- **`rules-service/`** — FastAPI + uvicorn backend. Owns the MTG comprehensive rules data, exposes `GET /rule/random`.
- **`k8s/`** — Raw Kubernetes manifests (no Kustomize/Helm at this scale).
- **`terraform/`** — VPC, EKS cluster, ECR, S3 (later), and supporting IAM.
- **`.github/`** — CODEOWNERS, workflows (Semgrep, TruffleHog, Trivy, pre-commit), Dependabot config.

## Repo conventions

- **Solo development with documented admin bypass.** `CODEOWNERS` lists me as the sole owner. Branch protection on `main` requires code-owner review, but admin bypass is explicitly enabled because I'm the only developer. Every bypass is logged in GitHub's audit log and surfaced on the PR as a "Merged without required review" event. In a real team the file would list at least two owners and bypass would be disabled.
- **Squash-merge only, linear history.** The branch protection ruleset on `main` permits squash as the only merge method and rejects non-fast-forward pushes, so `main` is a strict linear sequence of squash commits.
