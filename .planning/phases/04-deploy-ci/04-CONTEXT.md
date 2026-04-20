---
phase: 04-deploy-ci
type: context
created: 2026-04-20
---

# Phase 4 Context: Deploy & CI

## Phase Goal (from ROADMAP.md)

The aggregated site is reachable at `http://10.70.0.102:30081/` from a containerized deploy on Talos, and a GitHub Actions workflow rebuilds it nightly, on push to `main`, and on manual dispatch.

## Requirements Locked (from REQUIREMENTS.md)

- **DEPLOY-01** — Multi-stage Dockerfile (build stage + nginx runtime stage)
- **DEPLOY-02** — Kustomize bundle in `cos-docs/k8s/`, NodePort 30081 on Talos 10.70.0.102
- **DEPLOY-03** — Control-plane taint toleration, private registry `10.70.0.30:5000`
- **DEPLOY-04** — Site reachable at `http://10.70.0.102:30081/`
- **CI-01** — Nightly rebuild
- **CI-02** — On push to `main` + `workflow_dispatch`
- **CI-03** — Push built image to private registry (or produce deployable artifact)

## Locked Decisions (from discuss-phase, 2026-04-20)

### D-01: CI runner location — self-hosted on Talos host

Self-hosted `actions/runner` running as a systemd service on `10.70.0.102`.
- **Rationale:** `build-all-api.sh` needs working-tree access to 29 sibling repos at `/home/btc/github/`. Registry at `10.70.0.30:5000` is same internal network. GH-hosted would require VPN/tunnel plus remote-siblings checkout plumbing — strictly worse for this workspace.
- **Implication for planner:** One-time runner setup task (systemd unit + `cos-docs` repo runner registration token). Workflow uses `runs-on: self-hosted`.

### D-02: Sibling-repo acquisition — pull-on-start, continue-on-failure, + SHA manifest

CI runs `git -C <repo> pull --ff-only` on each of 29 siblings at job start, continue-on-failure (matches `scripts/pull-all.sh` pattern in workspace CLAUDE.md). Then writes `site-manifest.json` capturing per-repo commit SHAs into the built image.
- **Rationale:** Workspace convention is "no monorepo tooling" — submodules would be intrusive across 29 independent repos. Any sibling stuck on a non-main branch (the 4 `kubernetes`-branch repos cherry-picked in Phase 3) skips cleanly.
- **Trade-off accepted:** CI is stateful — builds against whatever is on disk. Acceptable for internal docs; `site-manifest.json` provides traceability (what commit of each repo produced this image).
- **Implication for planner:** Bash loop over repo list, emit JSON `{repo: sha}` map, COPY into Docker build stage so it lands at e.g. `/usr/share/nginx/html/site-manifest.json`.

### D-03: Registry push — every green build, multi-tag

On every successful build (nightly, push-to-main, manual), push to `10.70.0.30:5000/cos-docs` with three tags:
- `:<git-sha>` — reproducible pin
- `:latest` — convenience
- `:nightly-YYYYMMDD` — rollback target (only applied on nightly runs)
- **Rationale:** Self-hosted runner has direct network + filesystem access to registry; push is a local `docker push`. Multi-tag enables SHA-pinned deploys (reproducibility) alongside `:latest` (convenience).
- **Research must confirm:** Registry auth model — the existing `quant-dashboard` deploy already resolved whether `10.70.0.30:5000` accepts anonymous push or needs `docker login`. Planner should inherit whatever quant-dashboard's CI does.
- **Out of scope:** Tag retention / GC policy. If nightly tags balloon storage, a separate cleanup phase handles it.

### D-04: Build-failure policy — strict fail with override

CI exits non-zero if any of the 20 Python siblings fails pre-render or if aggregator `mkdocs build --strict` fails. `.build-all-api-status.md` is uploaded as a CI artifact on failure.
- **Escape hatch:** `workflow_dispatch` input `allow_partial: boolean` (default `false`) allows a dispatch-triggered build to succeed despite partial failure. Schedule + push-to-main runs always enforce strict.
- **Rationale:** "Best-effort image" is a slow-bleed failure mode — nav silently degrades. `build-all-api.sh` already writes a greppable status file; `grep -q "FAIL" || exit 1` is the enforcement point.
- **Implication for planner:** Workflow gate: `grep FAIL .build-all-api-status.md && [[ "$allow_partial" != "true" ]] && exit 1`.

### D-05: Deployment shape — 1 replica, modest limits, `kubernetes` branch

- 1 replica (not HPA). Docs site is static nginx with no state and trivial traffic.
- `resources.requests`: `cpu: 50m, memory: 64Mi`
- `resources.limits`: `cpu: 200m, memory: 256Mi`
- Tolerates `node-role.kubernetes.io/control-plane` taint (single-node cluster)
- Manifests live on a dedicated `kubernetes` branch of `cos-docs`, per workspace convention documented in CLAUDE.md / `KUBERNETES_BRANCHES_SUMMARY.md`
- **Manifest set (expected):** `namespace.yaml`, `deployment.yaml`, `service.yaml` (NodePort 30081), `kustomization.yaml`
- **Namespace:** `cos-docs`
- **Rationale:** HPA 2-10 fits user-facing apps (quant-dashboard). Internal docs don't need it. `kubernetes` branch separation keeps `main` infra-free and matches all 25+ sibling repos.
- **Implication for planner:** Dedicated plan for initial `kubernetes` branch creation + K8s manifest authoring. Manifests are NOT on `main`.

### D-06: Auto-deploy vs build-only — build + push only

CI produces and pushes the image. Deploy is manual via `kubectl rollout restart deployment/cos-docs -n cos-docs`. CI emits that exact command as its final log line.
- **Rationale:** No GitOps controller in cluster (per CLAUDE.md). Auto-rollout would require either ArgoCD/Flux adoption, SSH-to-host workflow, or polling — all expand Phase 4 scope. Manual deploy with nightly rebuild means staleness is bounded at 24h, which is fine for docs.
- **Deferred:** Optional `workflow_dispatch`-triggered deploy job (SSH + `kubectl rollout restart`). Roadmap-backlog candidate if friction becomes real.
- **Implication for planner:** No deploy automation in this phase. Final workflow step is a `echo "→ deploy with: kubectl rollout restart deployment/cos-docs -n cos-docs"`.

## Workspace Patterns to Mirror (researcher follow-up)

- `quant-dashboard/Dockerfile` — multi-stage build pattern (Vite build → nginx)
- `quant-dashboard/k8s/` — Kustomize layout with NodePort service, taint toleration
- `quant-dashboard/.github/workflows/` — existing CI workflow for image push to 10.70.0.30:5000
- `scripts/pull-all.sh` — pattern for iterating all sibling repos
- `KUBERNETES_BRANCHES_SUMMARY.md` — `kubernetes` branch convention documentation

## Out of Scope (deferred)

- Auto-deploy / GitOps controller
- Registry tag retention / GC
- HPA autoscaling
- TLS / ingress (NodePort only — internal cluster)
- Auth in front of the docs site (internal only, unauthenticated)
- `workflow_dispatch` deploy-only job (optional follow-up)

## Open Questions for Researcher

1. Confirm `10.70.0.30:5000` registry auth model by reading `quant-dashboard`'s CI workflow — anonymous push vs `docker login`?
2. Confirm Talos control-plane taint key/value (`node-role.kubernetes.io/control-plane:NoSchedule` is the standard but verify against other deployed manifests in the workspace).
3. Confirm the self-hosted runner installation pattern (systemd unit file location, user under which it runs, whether `/home/btc/github/` is accessible as that user).
4. Does any existing cos-docs CI workflow exist that needs to be superseded? (Expected: no — this is the first workflow.)

## Success Criteria Restated (from ROADMAP.md)

1. Multi-stage `Dockerfile` in `cos-docs/` builds static site → nginx image
2. `kubectl apply -k cos-docs/k8s/` deploys to Talos with control-plane toleration + private registry pull
3. `curl http://10.70.0.102:30081/` returns rendered aggregator landing page (HTTP 200)
4. GHA workflow runs on nightly + push-to-main + `workflow_dispatch`, produces deployable image in registry
