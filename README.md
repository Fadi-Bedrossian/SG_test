# Three-Tier App on AKS

A React frontend, a Node.js (Express) API and PostgreSQL, shipped with the complete toolchain:
**Docker**, **Kustomize** manifests for **AKS**, **Terraform + Helm** for Azure, and **GitHub Actions**
that build, test, scan, validate and publish on every push.

```
                   ┌─────────────────────────── AKS (Azure CNI overlay + Cilium) ───────────────────────────┐
  Internet ──► Static IP ──► ingress-nginx ──┬── /      ──► frontend (nginx, React build)                  │
                 (TLS via cert-manager)      └── /api   ──► api (Node.js) ── workload identity ──► Key Vault│
                   └──────────────────────────────────────────────┬────────────────────────────────────────┘
                                                                  │ private VNet subnet
                                                       PostgreSQL Flexible Server 16
```

## Repository layout

| Path | What it is |
|---|---|
| `frontend/` | React 18 + Vite app, Vitest tests, multi-stage Dockerfile → unprivileged nginx |
| `api/` | Express API (CRUD `/api/items`, `/healthz`, `/readyz`, `/metrics`), Jest unit + integration tests, SQL migrations, Dockerfile |
| `docker-compose.yml` | Full local stack (Postgres → migrations → API → frontend) |
| `k8s/base/` | Deployments, Services, Ingress, HPA, PDB, NetworkPolicies, ServiceAccount, Key Vault `SecretProviderClass` |
| `k8s/overlays/{dev,prod}/` | Namespace, replicas, sizing, and environment values injected via Kustomize `replacements` |
| `infra/terraform/` | Resource group, VNet, AKS, ACR, PostgreSQL Flexible Server, Key Vault, managed identity, Log Analytics, Helm releases |
| `infra/helm/cluster-issuers/` | Local Helm chart for Let's Encrypt ClusterIssuers |
| `.github/workflows/` | `ci.yml`, `infra.yml`, `deploy.yml`, `codeql.yml` |
| `scripts/bootstrap-azure.sh` | One-time: Terraform state storage + GitHub OIDC identity |

## Run locally

```bash
docker compose up --build        # http://localhost:8080
```

Or run each tier natively: `cd api && npm install && npm run dev` (needs a Postgres) and
`cd frontend && npm install && npm run dev` (proxies `/api` to `localhost:3000`).

> **First commit:** run `make lock` and commit both `package-lock.json` files. CI and the Dockerfiles
> fall back to `npm install` without them, but lockfiles give reproducible, faster builds.

## Pipelines

### `ci.yml` — every push and PR

| Stage | Jobs |
|---|---|
| **Build & test** | Frontend: ESLint, Vitest, Vite build · API: ESLint, Jest unit tests, integration tests against a real Postgres service container |
| **Validate** | `terraform fmt`, `terraform validate`, TFLint (azurerm ruleset) · `kustomize build` both overlays + kubeconform (incl. CRD schemas) · `helm lint` |
| **Scan** | Trivy filesystem (dependency CVEs, secrets, misconfig) → GitHub code scanning · Checkov (Terraform, K8s, Dockerfiles, Actions, Helm) · CodeQL (separate workflow) |
| **Publish** | Per image: build, Trivy image scan (SARIF + fail on CRITICAL), multi-arch push to GHCR tagged with commit SHA / branch / semver / `latest`, SBOM + provenance, cosign keyless signature |
| **Smoke** | `docker compose` end-to-end request through the frontend proxy |

Images publish on every push; pull requests stop after scanning.

### `infra.yml` — changes under `infra/`
Plans dev and prod on branches/PRs (output in the job summary); on `main` applies dev, then prod after approval.

### `deploy.yml` — after CI succeeds on `main`
Verifies cosign signatures → imports the images from GHCR into ACR (`az acr import`) → writes
`params.env` from `terraform output` and pins images to the commit SHA with `kustomize edit set image`
→ server-side dry run → `kubectl apply --server-side` → waits for rollout → in-cluster smoke test →
automatic `rollout undo` on failure. dev deploys automatically; prod waits for environment approval.

## Deploying to Azure

1. **Bootstrap** (once, as an Azure admin):
   ```bash
   ./scripts/bootstrap-azure.sh <owner>/<repo>
   ```
   Creates the state storage account and an Entra app trusted via GitHub OIDC, and fills in the
   backend config. It prints the three secrets to add to GitHub.
2. **GitHub settings**
   - Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - Environments: `dev`, `prod` (required reviewers), `dev-plan`, `prod-plan`
   - Variable `APP_HOST` on `dev` and `prod`
3. Set `letsencrypt_email` (and optionally `aks_admin_group_object_ids`) in `infra/terraform/environments/*.tfvars`.
4. Push to `main`. `infra.yml` provisions the platform; then point your DNS A record for `APP_HOST`
   at the `ingress_public_ip` output. `deploy.yml` ships the app on each subsequent green CI run.

The helm provider authenticates to AKS with `kubelogin` (local accounts are disabled), so running
Terraform from a laptop needs `az login` and [kubelogin](https://azure.github.io/kubelogin/) installed.

## Security posture

- No long-lived cloud credentials: GitHub → Azure via OIDC; pods → Key Vault via AKS workload identity.
- DB credentials live only in Key Vault and are synced to a Kubernetes Secret by the CSI driver.
- PostgreSQL has no public endpoint (delegated subnet + private DNS); TLS required.
- Pods run non-root with read-only root filesystem, all capabilities dropped, seccomp `RuntimeDefault`,
  and namespaces enforce Pod Security `restricted`. Default-deny NetworkPolicies, enforced by Cilium.
- Images are scanned, signed and carry SBOM + provenance; deploys verify signatures first.

## Things to adapt before production

- The API connects as the Postgres admin user for simplicity. Create a least-privilege role for the app.
- The AKS API server is public so GitHub-hosted runners can deploy; set `api_server_authorized_ip_ranges`
  or use self-hosted runners with a private cluster.
- Checkov runs report-only (`soft_fail: true`) until you triage its first run; see `.checkov.yaml` for documented skips.
- Pin third-party GitHub Actions to commit SHAs (Dependabot is configured to keep them current).
