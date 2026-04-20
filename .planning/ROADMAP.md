# Roadmap: cos-docs

**Created:** 2026-04-18
**Granularity:** coarse (4 phases)
**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

## Phases

- [ ] **Phase 1: Scaffold & Template** — Build the per-repo doc scaffold tool and pinned template that downstream content depends on
- [ ] **Phase 2: Content Migration** — Scaffold all ~25 sibling repos and migrate README/CLAUDE.md content into the per-repo docs trees
- [x] **Phase 3: Aggregator & API Strategy** — Compose all repos via mkdocs-monorepo-plugin, decide and implement the API-docs strategy, ship the workspace-wide diagram ✓ 2026-04-20
- [ ] **Phase 4: Deploy & CI** — Containerize, deploy to Talos NodePort 30083, automate nightly + on-push rebuilds

## Phase Details

### Phase 1: Scaffold & Template
**Goal**: A maintainer can run `scaffold.sh <repo>` and get a working, locally-previewable per-repo docs tree with pinned MkDocs Material + plugins, Mermaid rendering, and Pydantic-aware API rendering wired in.
**Depends on**: Nothing (first phase; spike findings already validated)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, DIAG-01, API-01
**Plans:** 2 plans
**Success Criteria** (what must be TRUE):
  1. Running `scaffold.sh <target-repo>` creates `docs/index.md`, `docs/architecture.md`, `docs/api.md`, `mkdocs.yml`, and a pinned requirements file in that repo
  2. Inside a freshly-scaffolded repo, `mkdocs serve` previews the site locally with no missing-plugin errors
  3. A Mermaid fenced code block in `docs/architecture.md` renders as an SVG diagram in the local preview
  4. A Pydantic v2 model with trailing-string field docstrings renders its field docs natively on `docs/api.md`
  5. Re-running `scaffold.sh` on an already-scaffolded repo does not clobber edited `docs/*.md` content
Plans:
- [x] 01-01-PLAN.md — scaffold.sh skeleton: arg parsing, repo-type detection, ownership/idempotency, --force, diff-on-overwrite (D-01,D-03,D-05..D-11,D-13) ✓ 2026-04-19 (32a5cf5)
- [x] 01-02-PLAN.md — embedded heredoc templates (mkdocs.yml + Mermaid superfences, pinned requirements-docs.txt, mkdocstrings api.md) + E2E smoke vs COS-Core (D-12,D-14..D-17, DIAG-01, API-01) ✓ 2026-04-18 (350edac, 287564a, ded6955)

### Phase 2: Content Migration
**Goal**: Every one of the ~25 sibling repos in `/home/btc/github/` has a populated `docs/` tree describing its purpose, architecture, and primary API surface — sourced from existing `README.md` + `CLAUDE.md`.
**Depends on**: Phase 1
**Requirements**: CONT-01, CONT-02, CONT-03, CONT-04, DIAG-02
**Success Criteria** (what must be TRUE):
  1. All ~25 sibling repos in `/home/btc/github/` have been scaffolded (each contains `docs/` and `mkdocs.yml`)
  2. Each repo's `docs/index.md` summarizes its purpose, language/runtime, and entry points
  3. Each repo's `docs/architecture.md` contains at least one Mermaid diagram of internal structure plus a written overview
  4. Each Python repo's `docs/api.md` lists the primary public modules/classes/functions targeted for `mkdocstrings` rendering
  5. `mkdocs serve` works locally inside any of the migrated repos with no broken references
**Plans:** 3 plans
Plans:
- [x] 02-01-PLAN.md — scaffold-all.sh wrapper + scaffold.sh --package amendment + PACKAGE_OVERRIDES (D-01, D-14, D-17) ✓ 2026-04-19 (63b2246, 78c5101)
- [x] 02-02-PLAN.md — Run rollout, triage failures, amend REQUIREMENTS.md DIAG-02, update CLAUDE.md project map (CONT-01, DIAG-02) ✓ 2026-04-19 (d8cffe6 cos-docs, 83683eb parent, 9 sibling commits; 9 OK / 2 FAIL / 19 SKIP)
- [ ] 02-03-PLAN.md — Hand-author per-repo content across 5 domain groups (CONT-02, CONT-03, CONT-04, D-05)

### Phase 3: Aggregator & API Strategy
**Goal**: A single `mkdocs build` from `cos-docs/` produces a complete static site composing all 25 repos, grouped by domain, with a workspace-wide architecture diagram and fully-rendered Python API pages using a decided-and-recorded API strategy.
**Depends on**: Phase 2
**Requirements**: AGGR-01, AGGR-02, AGGR-03, AGGR-04, AGGR-05, DIAG-03, API-02, API-03
**Success Criteria** (what must be TRUE):
  1. `mkdocs build` from `cos-docs/` completes with zero "reference not found" warnings and zero broken `!include` errors
  2. The built site's left-nav groups all ~25 repos under domain headers (Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure)
  3. The aggregator's top-level `docs/index.md` and `docs/architecture.md` exist and the architecture page renders a workspace-wide Mermaid data-flow diagram
  4. Material's default lunr search returns hits from across multiple aggregated repos for representative queries
  5. The API-docs strategy (mega-venv vs pre-rendered per-repo CI) is recorded as a Key Decision in `PROJECT.md` AND the chosen strategy is implemented such that every Python repo has populated API pages in the built site
**Plans:** 3 plans
Plans:
- [x] 03-01-PLAN.md — Aggregator mkdocs.yml + requirements-docs.txt + placeholder index.md + strict-build smoke (AGGR-01, AGGR-02, AGGR-04, AGGR-05) ✓ 2026-04-20 (d8b9027, eb1611d cos-docs + 4 sibling scaffold CPs)
- [x] 03-02-PLAN.md — build-all-api.sh per-repo isolated-venv loop + BTC-Forge/COS-MSE docstring fixes + PROJECT.md Key Decision (API-02, API-03) ✓ 2026-04-19 (5e174d1, 2a6c285, d519714)
- [x] 03-03-PLAN.md — Workspace Mermaid + full index.md + Architecture nav + final end-to-end strict-build (AGGR-03, DIAG-03) ✓ 2026-04-20 (e2e291f, 879f6fc, 18c6973)

### Phase 4: Deploy & CI
**Goal**: The aggregated site is reachable at `http://10.70.0.102:30083/` from a containerized deploy on Talos, and a GitHub Actions workflow rebuilds it nightly, on push to `main`, and on manual dispatch. *(NodePort amended from 30081 → 30083 on 2026-04-20; 30081 is held by pricefeed.)*
**Depends on**: Phase 3
**Requirements**: DEPLOY-01, DEPLOY-02, DEPLOY-03, DEPLOY-04, CI-01, CI-02, CI-03
**Success Criteria** (what must be TRUE):
  1. A multi-stage `Dockerfile` in `cos-docs/` builds the static site and serves it from nginx, producing a runnable image
  2. `kubectl apply -k cos-docs/k8s/` deploys the site to the Talos cluster with a `control-plane` taint toleration, pulling from the private registry `10.70.0.30:5000`
  3. `curl http://10.70.0.102:30083/` returns the rendered aggregator landing page with HTTP 200
  4. A GitHub Actions workflow runs on nightly schedule, on push to `main`, and on `workflow_dispatch`, and produces a deployable image (or pushes to the private registry)
**Plans:** 5 plans
Plans:
- [x] 04-01-PLAN.md — Multi-stage Dockerfile + nginx.conf + .dockerignore; local smoke-test image serves pre-built site/ (DEPLOY-01, DEPLOY-04) ✓ 2026-04-20 (9f274b1, 1efc7ad, 0cef9d6)
- [x] 04-02-PLAN.md — `kubernetes` branch (from main) + Kustomize bundle: namespace/deployment/service/kustomization, NodePort 30083, control-plane toleration, 1 replica (DEPLOY-02, DEPLOY-03, DEPLOY-04) ✓ 2026-04-20 (1646909 on kubernetes branch; 6875e05 port retarget on main)
- [x] 04-03-PLAN.md — Self-hosted runner install script (scripted `gh api`) + emit-site-manifest.sh + RUNNER-SETUP runbook (CI-01, CI-02, CI-03 partial — infra only; workflow in 04-04, E2E in 04-05) ✓ 2026-04-20 (acc1d7b, 040926e, 3c9daa9)
- [x] 04-04-PLAN.md — `.github/workflows/build.yml`: nightly + push + dispatch, in-place git sync (no actions/checkout), build-all-api --keep, strict-fail gate + allow_partial, if:always() restore, multi-tag push, rollout hint (CI-01, CI-02, CI-03, DEPLOY-01) ✓ 2026-04-20 (cab97f6 + 4934189; dispatch run 24673734857 green in 1m44s, registry :4934189 + :latest)
- [ ] 04-05-PLAN.md — End-to-end deploy verification: kubectl apply -k, curl assertions at 10.70.0.102:30083, DEPLOY-VERIFICATION.md transcript (DEPLOY-02, DEPLOY-03, DEPLOY-04)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffold & Template | 2/2 | Complete | 2026-04-18 |
| 2. Content Migration | 2/3 | In progress | - |
| 3. Aggregator & API Strategy | 3/3 | Complete | 2026-04-20 |
| 4. Deploy & CI | 4/5 | In progress | - |

## Coverage

All 26 v1 requirements mapped to exactly one phase. No orphans.

| Phase | Requirement Count | Requirements |
|-------|-------------------|--------------|
| 1 | 6 | SCAF-01, SCAF-02, SCAF-03, SCAF-04, DIAG-01, API-01 |
| 2 | 5 | CONT-01, CONT-02, CONT-03, CONT-04, DIAG-02 |
| 3 | 8 | AGGR-01, AGGR-02, AGGR-03, AGGR-04, AGGR-05, DIAG-03, API-02, API-03 |
| 4 | 7 | DEPLOY-01, DEPLOY-02, DEPLOY-03, DEPLOY-04, CI-01, CI-02, CI-03 |

---
*Roadmap created: 2026-04-18*
