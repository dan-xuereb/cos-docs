# cos-docs Kubernetes Manifests

Operator runbook for deploying the **cos-docs** aggregated MkDocs site to the
Talos cluster at `10.70.0.102`.

## Branch model (per D-05, D-08)

- **This directory (`k8s/`) lives on the `kubernetes` branch only.** It is NOT
  merged into `main`. The CI workflow on `main` builds the Docker image and
  pushes it to the private registry; Kubernetes manifests are maintained on a
  separate `kubernetes` branch to keep deploy churn out of the docs build.
- The `kubernetes` branch is **branched from `main`** (not orphan), matching
  the workspace precedent set by `quant-dashboard`. The Dockerfile and
  `mkdocs.yml` are therefore also present here — ignore them for apply
  purposes.

## First-time apply

Use a worktree to avoid branch-switching friction:

```bash
git -C /home/btc/github/cos-docs worktree add /tmp/cos-docs-k8s kubernetes
kubectl apply -k /tmp/cos-docs-k8s/k8s/
git -C /home/btc/github/cos-docs worktree remove /tmp/cos-docs-k8s
```

Or directly from this directory (after `git checkout kubernetes`):

```bash
kubectl apply -k k8s/
```

## Post-image-push rollout

After CI pushes a new image tag to `10.70.0.30:5000/cos-docs:latest`, force
the Deployment to re-pull:

```bash
kubectl rollout restart deployment/cos-docs -n cos-docs
kubectl rollout status  deployment/cos-docs -n cos-docs --timeout=120s
```

Because `imagePullPolicy: Always` is set, the rollout will fetch the latest
digest under the `:latest` tag.

## SHA-pinned deploys

Prefer pinning to an image digest for reproducibility. Edit
`kustomization.yaml`:

```yaml
images:
  - name: 10.70.0.30:5000/cos-docs
    newTag: abc1234     # <-- set to the CI-built tag or short SHA
```

Re-apply with `kubectl apply -k k8s/`.

## Contract: containerPort MUST track Dockerfile EXPOSE

`deployment.yaml` declares `containerPort: 8080`. This value **must match**
`EXPOSE 8080` in the `Dockerfile` on `main`. If the Dockerfile port ever
changes (e.g. to 9090), this manifest MUST be updated in lockstep or pods
will CrashLoop on readiness-probe failure.

## External entrypoint

- **NodePort 30083** on `10.70.0.102` (Talos control-plane / single-node cluster).
- Port 30083 was verified free at branch creation (plan 04-02 pre-flight).
- No Ingress / no Service TLS — the docs are internal-only per CONTEXT.md.

## Registry

Manifests reference `10.70.0.30:5000/cos-docs` — an insecure/anonymous
registry on the Talos containerd `insecure-registries` list (inherited from
the quant-dashboard precedent). **No `imagePullSecrets` required.**

## Resource sizing

- `requests`: 50m CPU / 64Mi memory
- `limits`:   200m CPU / 256Mi memory
- `replicas`: 1 (docs traffic is trivial; no HPA)

## Security posture

- `runAsNonRoot: true` with `runAsUser: 101` (nginx user in the image).
- `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`.
- `seccompProfile.type: RuntimeDefault`.
- `readOnlyRootFilesystem` intentionally NOT set — nginx writes pid + cache
  at runtime (documented in research as accepted).

## Health probes

Both liveness and readiness hit `GET /health` on port 8080, served by the
nginx stub response configured in the main-branch `nginx.conf` (plan 04-01).
