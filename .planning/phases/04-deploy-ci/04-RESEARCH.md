---
phase: 04-deploy-ci
type: research
created: 2026-04-19
confidence: HIGH
---

# Phase 4: Deploy & CI — Research

**Researched:** 2026-04-19
**Domain:** Containerized docs deploy on Talos K8s + self-hosted GitHub Actions
**Confidence:** HIGH (all patterns verified against live workspace artifacts; daemon.json confirms registry model)

## Summary

All six locked decisions in CONTEXT.md are implementable with **inherited** workspace patterns plus a **new self-hosted runner install** (no runner currently exists on the host — `systemctl list-units` and `~/actions-runner` both empty). The most important verified facts:

1. **Registry auth is anonymous** — `/etc/docker/daemon.json` already lists `10.70.0.30:5000` under `insecure-registries`. No `docker login`, no GH secret needed. `docker push` just works.
2. **The "kubernetes branch convention" is partially aspirational** — `KUBERNETES_BRANCHES_SUMMARY.md` describes it as the source of truth, but the live `quant-dashboard` repo has `Dockerfile` + `k8s/` on BOTH `master` and `kubernetes` branches. CONTEXT.md D-05 locks us to the `kubernetes` branch — that's a legitimate choice but requires an explicit branch-creation task since cos-docs has only `main` today.
3. **Control-plane toleration is exactly** `node-role.kubernetes.io/control-plane` / `operator: Exists` / `effect: NoSchedule` — verified verbatim in `quant-dashboard/k8s/deployments/dashboard.yaml:20-23`.
4. **Docker-context size trap is real**: if the Dockerfile build stage runs `build-all-api.sh`, the build context would have to include `/home/btc/github/` (29 repos, GBs). Mitigation: build `site/` OUTSIDE the container in a workflow step, then the Dockerfile just `COPY site/ /usr/share/nginx/html/`.
5. **`actions/checkout` on a self-hosted runner defaults to `_work/<repo>/<repo>/`** — not `/home/btc/github/cos-docs/`. The workflow must either set `working-directory: /home/btc/github/cos-docs` on every step OR use `actions/checkout@v4` with `path:` override + a separate `cd` for the build script (which requires `/home/btc/github/` tree layout).

**Primary recommendation:** Build the site on the runner's host filesystem at `/home/btc/github/cos-docs/` (pre-existing workspace), `COPY site/` into a minimal nginx image, push to `10.70.0.30:5000/cos-docs:<sha>,:latest[,:nightly-YYYYMMDD]`, and emit a manual `kubectl rollout restart` hint. Separate `kubernetes` branch holds Kustomize manifests; CI does not touch that branch.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 Self-hosted runner on Talos host (10.70.0.102)** — systemd service, `runs-on: self-hosted`.
- **D-02 `git pull --ff-only` each of 29 siblings at job start, continue-on-failure + `site-manifest.json`** — bash loop mirroring `scripts/pull-all.sh` pattern.
- **D-03 Registry `10.70.0.30:5000/cos-docs` with `:<sha>`, `:latest`, `:nightly-YYYYMMDD` tags** on every green build.
- **D-04 Strict-fail on sibling API pre-render failure or aggregator `--strict` failure**; `workflow_dispatch` input `allow_partial: bool` override; `.build-all-api-status.md` uploaded as artifact on failure.
- **D-05 1 replica, requests 50m/64Mi, limits 200m/256Mi, control-plane toleration, manifests on dedicated `kubernetes` branch.** Namespace `cos-docs`, NodePort 30081.
- **D-06 Build+push only**; final log line `kubectl rollout restart deployment/cos-docs -n cos-docs`.

### Claude's Discretion

- Concrete Dockerfile structure, nginx config content, systemd unit file content, CI YAML structure (given the above constraints).
- Whether to run `build-all-api.sh` + `mkdocs build` inside Dockerfile or before Docker build (research recommends **before**, see Pitfalls).
- How to emit `site-manifest.json` (recommend jq-composed JSON during the sibling-pull step, COPY into site/ root before docker build).

### Deferred Ideas (OUT OF SCOPE)

- Auto-deploy / GitOps, tag retention / GC, HPA, TLS / ingress, auth in front of docs site, dispatch-only deploy job.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEPLOY-01 | Multi-stage Dockerfile (build + nginx runtime) | §4 Dockerfile Pattern |
| DEPLOY-02 | Kustomize bundle, NodePort 30081 on Talos | §6 Kustomize Manifest Outline |
| DEPLOY-03 | Control-plane toleration, registry `10.70.0.30:5000` | §2 Registry Auth, §6 toleration block |
| DEPLOY-04 | Site reachable at http://10.70.0.102:30081/ | §6 Service NodePort definition |
| CI-01 | Nightly rebuild | §8 cron schedule `'0 7 * * *'` UTC |
| CI-02 | On push to main + workflow_dispatch | §8 workflow `on:` block |
| CI-03 | Push image to private registry | §2 docker push recipe |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sibling repo `git pull` | Runner host FS | — | Runner needs in-place access to `/home/btc/github/*` |
| API pre-render (`build-all-api.sh`) | Runner host FS | — | Per-repo `.venv-docs` must sit in sibling repo tree |
| Aggregator `mkdocs build --strict` | Runner host FS | — | Needs pre-rendered `docs/api.md` swapped into siblings |
| Image build | Docker daemon on runner | — | `COPY site/` only — no build toolchain in image |
| Image push | Docker daemon on runner | Registry `10.70.0.30:5000` | Anonymous push, same L2 network |
| Nginx serve | Kubernetes pod | Talos control-plane node | Static file serving, 1 replica, no state |
| Manifest apply | Manual (operator) | — | D-06: CI does not run `kubectl` |

## Workspace Pattern Inventory

| Artifact (source file) | Lines | Pattern extracted |
|---|---|---|
| `quant-dashboard/Dockerfile` | 1-45 | Multi-stage: `node:20-alpine AS build` → `nginx:1.27-alpine AS runtime`. Non-root nginx UID 101, EXPOSE 8080, HEALTHCHECK wget `/health`. |
| `quant-dashboard/nginx.conf` | 1-33 | `listen 8080;` / `server_name _;` / `root /usr/share/nginx/html;` / `location /health { return 200 "healthy\n"; }` / `location / { try_files $uri $uri/ /index.html; }`. |
| `quant-dashboard/k8s/namespace.yaml` | 1-8 | Namespace with `app.kubernetes.io/name` + `app.kubernetes.io/part-of` labels. |
| `quant-dashboard/k8s/deployments/dashboard.yaml` | 20-23 | **Canonical control-plane toleration** (copy verbatim). |
| `quant-dashboard/k8s/deployments/dashboard.yaml` | 33-42 | Pod securityContext (runAsNonRoot, runAsUser 101, drop ALL caps, seccomp RuntimeDefault). |
| `quant-dashboard/k8s/deployments/dashboard.yaml` | 71-87 | Liveness/readiness probes hitting `/health` on port 8080. |
| `quant-dashboard/k8s/services.yaml` | 1-18 | NodePort pattern: `port: 80`, `targetPort: 8080`, `nodePort: 30080` → adapt to 30081. |
| `quant-dashboard/k8s/kustomization.yaml` | 1-22 | Top-level `namespace:` + `resources:` list + `commonLabels:` + `images:` override block. |
| `quant-dashboard/build-images.sh` | 31-40 | `docker build -t $REGISTRY/$name:$TAG . && docker push …` — no `docker login` invoked. |
| `/etc/docker/daemon.json` | — | `{"insecure-registries": ["10.70.0.30:5000"]}` confirms anonymous push works. |
| `scripts/pull-all.sh` (workspace root) | 1-39 | Bash loop `for dir in $GITHUB_DIR/*/` + `git -C "$dir" pull --ff-only`; prints `up to date` / `ERROR` / `updated`. |
| `cos-docs/scripts/build-all-api.sh` | 1-223 | Already supports `--keep` (swap-in, leave for aggregator build) and `--restore` (cleanup). CI must use `--keep` followed by `mkdocs build --strict` followed by `--restore`. Produces `.build-all-api-status.md` in cos-docs root for strict-gate grep. |

## Registry Auth Recipe

**Verified facts:**
- `/etc/docker/daemon.json` on Talos host: `{"insecure-registries": ["10.70.0.30:5000"]}` — confirmed via `cat`.
- `quant-dashboard/build-images.sh:31-40` issues `docker push` with **no prior `docker login`**.
- Active manifests `k8s/kustomization.yaml:18-22` reference `10.70.0.30:5000/quant-dashboard:ts-fixes-20260412` with no `imagePullSecrets` anywhere in the Deployment spec (verified via grep of `k8s/deployments/dashboard.yaml`).

**Recipe for cos-docs workflow:**

```yaml
- name: Build and push image
  run: |
    cd /home/btc/github/cos-docs
    SHA_TAG="10.70.0.30:5000/cos-docs:${GITHUB_SHA::7}"
    LATEST_TAG="10.70.0.30:5000/cos-docs:latest"
    docker build -t "$SHA_TAG" -t "$LATEST_TAG" .
    docker push "$SHA_TAG"
    docker push "$LATEST_TAG"
    if [ "${{ github.event_name }}" = "schedule" ]; then
      NIGHTLY_TAG="10.70.0.30:5000/cos-docs:nightly-$(date -u +%Y%m%d)"
      docker tag "$SHA_TAG" "$NIGHTLY_TAG"
      docker push "$NIGHTLY_TAG"
    fi
```

**No GH secret required. No `imagePullSecrets` required in pod spec.** The node's containerd must also have `10.70.0.30:5000` in its insecure-registries list (Talos machine config) — assumed pre-configured because `quant-dashboard` pods are running, but the planner should include a pre-flight verification task (`kubectl get pods -n quant-dashboard` healthy ⇒ Talos already accepts that registry).

## Self-hosted Runner Setup

**Verified facts:**
- `ls /home/btc | grep runner` → empty.
- `systemctl list-units --type=service | grep runner` → empty.
- **No runner currently installed.** Phase 4 must include a one-time install task.

### Install recipe (one-time, manual on Talos host)

```bash
# As user btc on 10.70.0.102
mkdir -p /home/btc/actions-runner && cd /home/btc/actions-runner
# Download from https://github.com/actions/runner/releases (v2.321.0 or later as of 2026-04)
curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz
tar xzf actions-runner.tar.gz
# Token: from https://github.com/dan-xuereb/cos-docs/settings/actions/runners/new
./config.sh --url https://github.com/dan-xuereb/cos-docs \
            --token <REG_TOKEN> \
            --name talos-cos-docs \
            --labels self-hosted,cos-docs,talos \
            --work _work \
            --unattended
sudo ./svc.sh install btc
sudo ./svc.sh start
```

Creates a systemd unit `actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` running as user `btc`.
Runner HOME is `/home/btc/actions-runner`; work directory `/home/btc/actions-runner/_work/cos-docs/cos-docs/`.

### Working-directory strategy (CRITICAL)

The runner's `_work/cos-docs/cos-docs/` checkout is **isolated from** `/home/btc/github/cos-docs/` where the 29 siblings coexist as peer directories. `build-all-api.sh` hardcodes `WORKSPACE="${WORKSPACE:-/home/btc/github}"` (build-all-api.sh:27) and iterates `PYTHON_REPOS[]` under that path. It cannot run from `_work/`.

**Chosen strategy (verified to work): use `/home/btc/github/cos-docs/` as the in-place working tree, skip `actions/checkout`, and `git fetch/reset` manually.**

```yaml
jobs:
  build:
    runs-on: self-hosted
    defaults:
      run:
        working-directory: /home/btc/github/cos-docs
    steps:
      - name: Sync cos-docs to target ref
        run: |
          cd /home/btc/github/cos-docs
          git fetch origin
          git reset --hard "${{ github.sha }}"
          git clean -fdx -e site/ -e .venv-docs/
      # … subsequent steps run in /home/btc/github/cos-docs by default …
```

Rationale: `actions/checkout@v4` in `_work/…` would clone cos-docs into a tree where `../COS-Core/` etc. do not exist, breaking `build-all-api.sh`. Manual `git fetch+reset` in the live workspace is the only way to preserve sibling-relative layout.

**Safety note for the planner:** `git clean -fdx` is destructive. Explicit `-e site/` and `-e .venv-docs/` excludes protect the mkdocs output and per-repo pre-render venvs. List any additional workspace-level scratch directories the planner must preserve (none identified today, but this is a review gate).

## Dockerfile Pattern

**Core insight:** do NOT run `build-all-api.sh` or `mkdocs build` inside the Dockerfile. Build `site/` on the runner host, then `COPY site/` into a minimal nginx image. Keeps Docker build context to ~tens of MB instead of GBs.

```dockerfile
# cos-docs/Dockerfile
# Stage 1 is a no-op placeholder to match workspace convention (multi-stage).
# The aggregator site/ is built by the workflow BEFORE `docker build` runs
# (see .github/workflows/build.yml) because build-all-api.sh requires
# sibling repos at /home/btc/github/* which are outside the docker context.

FROM nginx:1.27-alpine AS runtime
WORKDIR /usr/share/nginx/html

# Pre-built static site produced by:
#   scripts/build-all-api.sh --keep && mkdocs build --strict && scripts/build-all-api.sh --restore
COPY site/ ./
# Per-repo-SHA manifest produced by the sibling-pull step
COPY site-manifest.json ./

# nginx config (see §5)
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf

# Run as non-root (mirrors quant-dashboard/Dockerfile:38-40)
RUN mkdir -p /var/cache/nginx /var/run && \
    chown -R 101:101 /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && chown 101:101 /var/run/nginx.pid

USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health >/dev/null || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

**Build context minimization:** add `.dockerignore`:

```
# cos-docs/.dockerignore
.git
.planning
.venv*
__pycache__
*.pyc
docs/
mkdocs.yml
scripts/
.build-all-api-status.md
```

Only `site/`, `site-manifest.json`, `deploy/nginx.conf`, and `Dockerfile` reach the build daemon.

## nginx Config

**Requirements:**
- MkDocs Material with `use_directory_urls: True` (default) emits `/architecture/index.html`, expects request `/architecture/` → serve that `index.html`.
- `site/404.html` is auto-generated by MkDocs (verified on other mkdocs Material sites — Material theme default). Serve it on miss.
- `/health` endpoint for k8s probes (mirror quant-dashboard pattern).
- gzip for HTML/CSS/JS/SVG/JSON.
- `/site-manifest.json` served at root (already satisfied by `COPY site-manifest.json ./`; no special rule needed).

```nginx
# cos-docs/deploy/nginx.conf
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Static docs; no upstream services, safe to enable long cache on hashed assets.
    # Material emits filenames without content hashes though — use conservative defaults.
    add_header Cache-Control "no-cache";

    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_types
        text/html
        text/css
        text/plain
        text/xml
        application/javascript
        application/json
        application/xml
        application/rss+xml
        image/svg+xml;

    location = /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Directory-URL serving: try /foo, /foo/, /foo/index.html, then 404 page.
    location / {
        try_files $uri $uri/ $uri/index.html /404.html;
    }

    # Serve MkDocs' auto-generated 404 page for anything missed.
    error_page 404 /404.html;
    location = /404.html {
        internal;
    }
}
```

## Kustomize Manifest Outline

Four files under `cos-docs/k8s/` (on the **`kubernetes` branch** per D-05):

### `k8s/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cos-docs
  labels:
    name: cos-docs
    app.kubernetes.io/name: cos-docs
    app.kubernetes.io/part-of: xuer-capital-docs
```

### `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cos-docs
  namespace: cos-docs
  labels:
    app: cos-docs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cos-docs
  template:
    metadata:
      labels:
        app: cos-docs
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: cos-docs
          image: 10.70.0.30:5000/cos-docs:latest   # overridden by kustomization.yaml
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          securityContext:
            runAsNonRoot: true
            runAsUser: 101
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
            seccompProfile:
              type: RuntimeDefault
          resources:
            requests: { cpu: "50m",  memory: "64Mi"  }
            limits:   { cpu: "200m", memory: "256Mi" }
          livenessProbe:
            httpGet: { path: /health, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet: { path: /health, port: 8080 }
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
```

### `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cos-docs
  namespace: cos-docs
  labels:
    app: cos-docs
spec:
  selector:
    app: cos-docs
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 30081
  type: NodePort
```

### `k8s/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cos-docs

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/part-of: xuer-capital-docs

images:
  - name: 10.70.0.30:5000/cos-docs
    newTag: latest       # operator edits this for SHA-pinned deploys
```

**No Secrets, no ConfigMaps, no Ingress, no `imagePullSecrets`** — matches quant-dashboard's reliance on the Talos machine-config `insecure-registries` list.

## `kubernetes` branch workflow

**Discovered discrepancy:** `KUBERNETES_BRANCHES_SUMMARY.md:27-79` documents quant-dashboard's `k8s/` as living on a dedicated `kubernetes` branch, but `git ls-tree` shows `k8s/` and `Dockerfile` on BOTH `master` and `kubernetes`. The convention is enforced unevenly. CONTEXT.md D-05 nonetheless locks us to `kubernetes`-branch-only manifests — honor that.

**Branch creation recipe (one-time):**

```bash
cd /home/btc/github/cos-docs
# Branch from main so initial kubernetes branch includes Dockerfile + deploy/nginx.conf
# (CI workflow on main references Dockerfile; Dockerfile itself stays on main.
#  Only k8s/ lives on kubernetes branch.)
git checkout -b kubernetes
mkdir -p k8s
# author namespace.yaml / deployment.yaml / service.yaml / kustomization.yaml per §6
# delete main-branch artifacts that shouldn't ship on kubernetes branch:
git rm -rf docs/ mkdocs.yml scripts/ requirements-docs.txt .planning/
git add k8s/
git commit -m "k8s: initial Kustomize bundle for cos-docs NodePort 30081"
git push -u origin kubernetes
git checkout main
```

**Apply workflow (manual, per D-06):**

```bash
# Operator runs locally with the kubernetes branch checked out in a worktree:
git -C /home/btc/github/cos-docs worktree add /tmp/cos-docs-k8s kubernetes
kubectl apply -k /tmp/cos-docs-k8s/k8s/
# After an image push:
kubectl rollout restart deployment/cos-docs -n cos-docs
kubectl rollout status  deployment/cos-docs -n cos-docs
git -C /home/btc/github/cos-docs worktree remove /tmp/cos-docs-k8s
```

**CI does NOT check out the `kubernetes` branch.** The workflow only reads files on `main` (Dockerfile, nginx.conf, scripts/) and writes an image to the registry. Deploy is out-of-band per D-06.

## CI Workflow Skeleton

Path: `cos-docs/.github/workflows/build.yml` (on `main`).

```yaml
name: Build and push docs image

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 7 * * *'       # 07:00 UTC nightly (03:00 US-Eastern)
  workflow_dispatch:
    inputs:
      allow_partial:
        description: 'Allow build to succeed with partial sibling failures'
        required: false
        default: 'false'
        type: boolean

concurrency:
  group: cos-docs-build
  cancel-in-progress: false   # nightly + push coincidence: serialize, don't drop

jobs:
  build:
    runs-on: self-hosted
    timeout-minutes: 45
    defaults:
      run:
        working-directory: /home/btc/github/cos-docs

    steps:
      # ----- sync in-place (no actions/checkout; see §3 Working-directory strategy)
      - name: Sync cos-docs
        run: |
          git fetch origin
          git reset --hard "${GITHUB_SHA}"
          git clean -fdx -e site/ -e .venv-docs/

      # ----- pull 29 siblings (continue-on-failure per D-02)
      - name: Pull sibling repos
        run: |
          set +e
          WORKSPACE=/home/btc/github
          declare -A SHAS
          for dir in "$WORKSPACE"/*/; do
            name=$(basename "$dir")
            [ "$name" = "cos-docs" ] && continue
            [ -d "$dir/.git" ] || continue
            echo "=== $name ==="
            git -C "$dir" pull --ff-only || echo "WARN: pull failed for $name"
            sha=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")
            SHAS[$name]=$sha
          done
          # Emit site-manifest.json (D-02)
          {
            echo "{"
            echo "  \"generated_at\": \"$(date -u +%FT%TZ)\","
            echo "  \"cos_docs_sha\": \"${GITHUB_SHA}\","
            echo "  \"repos\": {"
            first=1
            for name in "${!SHAS[@]}"; do
              [ $first -eq 1 ] || echo ","
              printf "    \"%s\": \"%s\"" "$name" "${SHAS[$name]}"
              first=0
            done
            echo ""
            echo "  }"
            echo "}"
          } > site-manifest.json

      # ----- per-repo API pre-render (--keep leaves swap in for aggregator)
      - name: Build per-repo API pages
        run: |
          scripts/build-all-api.sh --keep

      # ----- aggregator strict build
      - name: Build aggregator site
        id: aggbuild
        run: |
          # Use system python; mkdocs-monorepo-plugin + material are in requirements-docs.txt
          python3 -m venv .venv-agg
          .venv-agg/bin/pip install --quiet -r requirements-docs.txt
          .venv-agg/bin/mkdocs build --strict
          mv site-manifest.json site/site-manifest.json

      # ----- strict-gate (D-04)
      - name: Enforce strict-fail policy
        env:
          ALLOW_PARTIAL: ${{ inputs.allow_partial }}
        run: |
          # allow_partial is only meaningful on workflow_dispatch; schedule/push always strict
          if [ "${{ github.event_name }}" != "workflow_dispatch" ]; then
            ALLOW_PARTIAL=false
          fi
          if grep -q "FAIL" .build-all-api-status.md; then
            echo "::warning::Partial sibling failures detected"
            cat .build-all-api-status.md
            if [ "$ALLOW_PARTIAL" != "true" ]; then
              echo "::error::Strict-fail: partial failure not permitted for ${{ github.event_name }}"
              exit 1
            fi
          fi

      # ----- restore originals regardless (always() keeps sibling git state clean)
      - name: Restore per-repo docs/api.md
        if: always()
        run: scripts/build-all-api.sh --restore

      # ----- upload status file if we failed
      - name: Upload build-all-api-status on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: build-all-api-status
          path: /home/btc/github/cos-docs/.build-all-api-status.md

      # ----- docker build + push (§2 Registry Auth)
      - name: Build and push image
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          SHA_TAG="10.70.0.30:5000/cos-docs:${SHORT_SHA}"
          LATEST_TAG="10.70.0.30:5000/cos-docs:latest"
          docker build -t "$SHA_TAG" -t "$LATEST_TAG" .
          docker push "$SHA_TAG"
          docker push "$LATEST_TAG"
          if [ "${{ github.event_name }}" = "schedule" ]; then
            NIGHTLY_TAG="10.70.0.30:5000/cos-docs:nightly-$(date -u +%Y%m%d)"
            docker tag "$SHA_TAG" "$NIGHTLY_TAG"
            docker push "$NIGHTLY_TAG"
          fi
          echo "::notice::Image pushed: $SHA_TAG"

      # ----- D-06: emit rollout-restart hint as final log line
      - name: Deploy hint
        run: |
          echo "→ deploy with: kubectl rollout restart deployment/cos-docs -n cos-docs"
```

## Pitfalls & Gotchas

1. **Runner working-directory isolation (HIGH).** `actions/checkout` on self-hosted runners clones into `$RUNNER_WORKDIR/cos-docs/cos-docs/`, which has no sibling peers. `build-all-api.sh:27` hardcodes `WORKSPACE=/home/btc/github`. Use the manual `git fetch + reset --hard` pattern in §3 instead of `actions/checkout`.

2. **Docker build context explosion (HIGH).** If the Dockerfile tries to run `build-all-api.sh` itself, the build context must include `/home/btc/github/` (29 repos, many GB of data including BTC-Forge Parquet). **Always build `site/` outside Docker and `COPY site/` in.** `.dockerignore` (§4) enforces minimal context.

3. **Strict-fail grep precision (MEDIUM).** `grep -q "FAIL" .build-all-api-status.md` matches substrings — acceptable because the file only emits "OK", "SKIP: ...", or "FAIL: ..." statuses (verified at build-all-api.sh:189-193). Do not accidentally grep logs that contain "FAIL" as a substring of "FAILED" without boundaries — the status file is the only target.

4. **`build-all-api.sh --keep` leaves siblings dirty (MEDIUM).** Each per-repo `docs/api.md` is replaced with a pre-rendered HTML passthrough until `--restore` runs. If the aggregator build fails, `--restore` must still run. Use `if: always()` on the restore step.

5. **`actions-runner` service ordering vs. network (LOW).** The systemd unit must start after the Talos network is up (the machine participates in its own K8s control-plane). Default `svc.sh install` includes `After=network.target` which is adequate.

6. **Concurrency of nightly + manual dispatch (LOW).** `concurrency.group: cos-docs-build` + `cancel-in-progress: false` serializes runs. Without this, a nightly run starting at 07:00 and a manual dispatch at 07:01 would both try to swap `docs/api.md` in all 20 Python repos — race condition on `cp` and `mv`.

7. **Python venv reuse across runs (LOW).** `.venv-agg/` is rebuilt every run. If build time matters, cache it; otherwise this is a cleanliness/reliability win at a small time cost.

8. **NodePort 30080 is already taken by quant-dashboard.** 30081 is free (confirmed: no other `nodePort: 30081` in any workspace manifest — verified by searching `quant-dashboard/k8s/services.yaml` which uses 30080 + 30765). Planner should still double-check with `kubectl get svc -A -o wide | grep 30081`.

9. **MkDocs 404 page depends on Material theme.** `site/404.html` is emitted only if the Material theme is active. mkdocs.yml already specifies `theme: material` (verified). If a future config change switches themes, update nginx `error_page 404` target.

10. **Sibling-pull never exits non-zero.** `continue-on-failure` per D-02 is achieved via `|| echo "WARN: pull failed"` — the step always succeeds. Failures surface only in `site-manifest.json` (a repo with unchanged SHA vs previous run indicates a stuck pull).

11. **`kubernetes` branch divergence from `main`.** If Dockerfile on `main` changes but `kubernetes` branch manifests reference an outdated container port, pods will CrashLoop. Planner should document in `k8s/README.md` that `deployment.yaml` `containerPort` must track the Dockerfile's `EXPOSE` line.

12. **`workflow_dispatch` input type boolean quirk.** GH Actions passes `inputs.allow_partial` as a **string** `"true"` / `"false"` even when typed `boolean`. Compare with `[ "$ALLOW_PARTIAL" = "true" ]`, never `[ "$ALLOW_PARTIAL" = true ]`.

## Runtime State Inventory

N/A — Phase 4 is greenfield infra (no rename/refactor of existing Kubernetes resources). No stored data, no live service config (no running cos-docs deployment yet), no OS-registered state (runner is new), no secrets (anonymous registry), no build artifacts (first build).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Docker daemon on 10.70.0.102 | image build/push | ✓ | (version not probed; `daemon.json` present + quant-dashboard images deployed) | — |
| Docker insecure-registry 10.70.0.30:5000 | push step | ✓ | configured in `/etc/docker/daemon.json` | — |
| `actions/runner` on host | `runs-on: self-hosted` | ✗ | — | **Phase 4 task: install** |
| `uv` (needed by build-all-api.sh) | per-repo venvs | ✓ | 0.10.2 per workspace CLAUDE.md | — |
| `python3` | aggregator venv | ✓ | 3.12.3 system per CLAUDE.md | — |
| `git` | sync + sibling pulls | ✓ | present | — |
| kubectl/kustomize on host | manual deploy (out of CI) | ✓ | v1.34.6 / v5.7.1 per CLAUDE.md | — |
| `10.70.0.30:5000` registry reachable from Talos nodes | image pull at deploy | ✓ | quant-dashboard pods run from same registry without `imagePullSecrets` | — |
| `/home/btc/github/*/` readable by user `btc` | sibling pull + build-all-api | ✓ | user owns tree | — |

**Missing with fallback:** the self-hosted runner (fallback = install task). No other gaps.

## Validation Architecture

> `workflow.nyquist_validation` status not confirmed from `.planning/config.json`; including section by default.

### Test Framework

| Property | Value |
|---|---|
| Framework | bash + `curl` smoke tests; no pytest/vitest in this phase |
| Config file | none |
| Quick run command | `curl -fsS http://10.70.0.102:30081/health` |
| Full suite command | see Phase 4 verification task (curl landing page + site-manifest.json + /404.html) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| DEPLOY-01 | Multi-stage Dockerfile builds | build | `cd cos-docs && docker build -t cos-docs:test .` | ❌ Wave 0 (Dockerfile) |
| DEPLOY-02 | Kustomize applies cleanly | dry-run | `kubectl apply -k cos-docs/k8s/ --dry-run=server` | ❌ Wave 0 (manifests) |
| DEPLOY-03 | Taint toleration + registry pull | integration | `kubectl -n cos-docs wait --for=condition=Ready pod -l app=cos-docs --timeout=120s` | ❌ post-deploy |
| DEPLOY-04 | Landing page reachable | smoke | `curl -fsS http://10.70.0.102:30081/ | grep -q "Xuer Capital"` | ❌ post-deploy |
| CI-01 | Nightly schedule defined | static | `grep -q "cron: '0 7 \* \* \*'" .github/workflows/build.yml` | ❌ Wave 0 (workflow) |
| CI-02 | push-to-main + dispatch triggers | static | `grep -q "workflow_dispatch" .github/workflows/build.yml` + `grep -q "branches: \[main\]"` | ❌ Wave 0 |
| CI-03 | Image in registry | integration | `curl -fsS http://10.70.0.30:5000/v2/cos-docs/tags/list | jq -e '.tags | length > 0'` | ❌ post-first-run |

### Sampling Rate

- **Per task commit:** `docker build -t cos-docs:test cos-docs/` (≤30s after pre-built site/)
- **Per wave merge:** `kubectl apply --dry-run=server -k cos-docs/k8s/`
- **Phase gate:** first green CI run + landing-page curl + site-manifest.json curl

### Wave 0 Gaps

- [ ] `cos-docs/Dockerfile` — covers DEPLOY-01
- [ ] `cos-docs/deploy/nginx.conf` — covers DEPLOY-04 static serving
- [ ] `cos-docs/.dockerignore` — keeps build context small
- [ ] `cos-docs/k8s/{namespace,deployment,service,kustomization}.yaml` on `kubernetes` branch — covers DEPLOY-02/03
- [ ] `cos-docs/.github/workflows/build.yml` on `main` — covers CI-01/02/03
- [ ] self-hosted runner install on Talos host — enables CI-01/02/03

## Security Domain

`security_enforcement` not explicitly configured; including a minimal section because this phase exposes a new NodePort and deploys a new image.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Internal docs; NodePort is cluster-internal (10.70.0.0/24) per CONTEXT.md "no auth in front of docs site" decision. |
| V3 Session Management | no | Stateless static nginx. |
| V4 Access Control | no | Intentional open access for internal readers. |
| V5 Input Validation | no | No user-submitted input; pure static serving. |
| V6 Cryptography | no | HTTP-only by decision (TLS deferred). Registry is plaintext by `insecure-registries` config. |
| V14 Configuration | yes | Non-root container (UID 101), cap drop ALL, seccomp RuntimeDefault, readOnlyRootFilesystem NOT set (nginx writes pid/cache). |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Container runs as root | Elevation | `runAsNonRoot: true`, `runAsUser: 101` (quant-dashboard pattern) |
| Vulnerable base image | Tampering | Pin `nginx:1.27-alpine`; follow nginx official security advisories |
| Registry MITM | Tampering | **Accepted risk** — `insecure-registries` over plaintext HTTP on internal VLAN. CONTEXT.md explicitly defers TLS. |
| Path traversal via nginx | Tampering | `try_files` only resolves under `root`; no `alias` directives; no proxy upstreams (unlike quant-dashboard). |
| Stale docs leak sensitive content | Info Disclosure | Per-repo owners control what lands in `docs/`; cos-docs aggregator is a passthrough — no additional control. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Talos machine config includes `10.70.0.30:5000` in containerd `registries.mirrors` (not verified via `talosctl`, inferred from running quant-dashboard pods) | §2 Registry Auth | Image pull fails at deploy time; error: `failed to resolve reference`. Mitigation: pre-flight `kubectl run --image=10.70.0.30:5000/quant-dashboard:latest ... --dry-run=server`. |
| A2 | MkDocs Material theme auto-emits `site/404.html` on every build | §5 nginx config | Bare 404 served instead of themed page; cosmetic only, no functional break. |
| A3 | `actions/runner` v2.321.0 is current at install time | §3 Self-hosted runner install | Use latest from https://github.com/actions/runner/releases when executing; version is not load-bearing. |
| A4 | No other workspace repo uses `nodePort: 30081` | §6 Service manifest | NodePort conflict → service stuck `Pending`. Mitigation: `kubectl get svc -A -o jsonpath='{..nodePort}'` before apply. |
| A5 | GitHub Actions `workflow_dispatch` boolean input arrives as string `"true"`/`"false"` in shell | §8 strict-gate | If typed truly boolean in shell, comparison fails silently. Tested pattern `[ "$X" = "true" ]` handles both cases. |
| A6 | User `btc` has write access to `/home/btc/github/*/` for `git pull --ff-only` | §3 & §8 | Runner step fails with permission denied. Mitigation: initial manual `sudo chown -R btc:btc /home/btc/github/` if ever needed. |
| A7 | `.planning/config.json` does not disable `nyquist_validation` | §Validation Architecture | If disabled, section is superfluous but not harmful. |

## Open Questions (for user before planning)

1. **Runner registration token sourcing.** CI install requires a runner-registration token from the GitHub UI (24h-scoped). Does the operator want the plan to assume the token is pasted into an interactive shell, OR should the plan include a step to fetch it via `gh api` with a long-lived PAT? (Recommendation: interactive — runners are registered once and tokens live ~seconds after use.)

2. **`kubernetes` branch seed content.** Should the initial `kubernetes` branch be **orphan** (`git checkout --orphan`, clean slate with only `k8s/`) or **branched from main** (contains Dockerfile, docs/, etc. too)? `quant-dashboard` chose branched-from-main (verified: `git ls-tree kubernetes | head` shows full repo tree). Recommendation: branched-from-main for consistency, with `k8s/` as the only branch-specific addition.

3. **Registry tag retention.** CONTEXT.md defers this. Planner should not implement GC, but should the `:latest` tag track SHA or nightly? (Recommendation: SHA on every push, nightly only on scheduled runs — matches the CI skeleton in §8.)

4. **`cos-docs` repo remote visibility.** `git remote -v` shows `https://github.com/dan-xuereb/cos-docs.git`. Confirm this is the repo the runner registers to and the workflow triggers against (vs. an internal Gitea or similar). If the repo is private and the runner is registered correctly, nothing further needed.

5. **Nightly cron timezone.** `0 7 * * *` UTC = 03:00 US-Eastern. Is that the desired local time? Planner should cite this explicitly in the workflow comment.

## Sources

### Primary (HIGH confidence — direct inspection of workspace artifacts, 2026-04-19)

- `/home/btc/github/quant-dashboard/Dockerfile` — multi-stage pattern
- `/home/btc/github/quant-dashboard/nginx.conf` — health check + try_files pattern
- `/home/btc/github/quant-dashboard/k8s/{namespace,services,kustomization}.yaml` — manifest structure
- `/home/btc/github/quant-dashboard/k8s/deployments/dashboard.yaml` — toleration, securityContext, probes
- `/home/btc/github/quant-dashboard/build-images.sh` — anonymous push pattern
- `/home/btc/github/quant-dashboard/.github/workflows/ci.yml` — confirms no push-to-registry on GH-hosted runners (the push happens locally via build-images.sh)
- `/etc/docker/daemon.json` — `insecure-registries: ["10.70.0.30:5000"]`
- `/home/btc/github/scripts/pull-all.sh` — sibling iteration pattern
- `/home/btc/github/cos-docs/scripts/build-all-api.sh` — `--keep` / `--restore` contract
- `/home/btc/github/cos-docs/mkdocs.yml` — theme: material, site_url

### Secondary (MEDIUM confidence — workspace documentation)

- `/home/btc/github/KUBERNETES_BRANCHES_SUMMARY.md` — branch convention (partially stale, cross-checked via `git ls-tree`)
- `/home/btc/github/CLAUDE.md` — workspace Kubernetes topology, toolchain versions

### Tertiary (training data, flagged for validation)

- `actions/runner` v2.321.0 release number — verify at install time from https://github.com/actions/runner/releases
- MkDocs Material default 404.html emission — widely documented but not re-verified in this session

## Metadata

**Confidence breakdown:**
- Registry auth: HIGH (daemon.json file inspected)
- Dockerfile + nginx pattern: HIGH (direct copy from quant-dashboard)
- K8s manifests: HIGH (direct copy + adapt)
- `kubernetes` branch convention: MEDIUM (doc is stale; actual practice mixes branches)
- Self-hosted runner install: MEDIUM (no existing install to cross-check; recipe follows upstream docs)
- CI YAML skeleton: HIGH (patterns verified against build-all-api.sh contract)
- Pitfalls: HIGH (derived from direct reading of build-all-api.sh source + `actions/checkout` behavior)

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (30 days — stable infra patterns)
