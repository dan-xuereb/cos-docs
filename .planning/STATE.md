---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-04-20T14:50:00Z"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 13
  completed_plans: 11
  percent: 85
# Note: Phase 3 complete (all 3 plans); Phase 2 still has 02-03 pending (content authoring).
# total_plans excludes Phase 4 (not yet planned at plan-granularity).
---

# State: cos-docs

**Initialized:** 2026-04-18

## Project Reference

**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

**Current Focus:** Phase 1 — Scaffold & Template

## Current Position

Phase: 4 (Deploy & CI) — IN PROGRESS
Plan: 3 of 5 complete

- **Phase:** 4 — Deploy & CI (3/5 plans complete)
- **Plan:** 04-03 (`acc1d7b` + `040926e` + `3c9daa9` on main) complete; self-hosted runner `talos-cos-docs` live (systemd `active`, Idle at github.com/dan-xuereb/cos-docs) with labels `self-hosted,cos-docs,talos`; `scripts/emit-site-manifest.sh` + `scripts/install-runner.sh` + `RUNNER-SETUP.md` shipped. CI-01/02/03 infra landed; satisfaction pending 04-04 workflow + 04-05 E2E.
- **Status:** 04-04 (`.github/workflows/build.yml`) unblocked — runner ready to accept jobs targeting `runs-on: self-hosted`. Phase 2 plan 02-03 (per-repo content authoring) remains pending; independent of Phase 4.
- **Progress:** [■■■■] Phase 4 underway; runner registered + systemd unit active, emit-site-manifest.sh verified (31 repos, 40-hex cos_docs_sha, ISO-8601 timestamp).

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases planned | 4 |
| Phases complete | 1 |
| Plans complete | 4 |
| v1 requirements mapped | 26/26 |
| Spikes completed | 4 (all ✓ VALIDATED) |

| Plan | Duration (s) | Tasks | Files | Commits |
|------|--------------|-------|-------|---------|
| 02-01 | 276 | 2 | 2 | 2 (63b2246, 78c5101) |
| 02-02 | 440 | 2 | 3 (cos-docs) + 1 (parent) + 9 (siblings) | 11 (d8cffe6, 83683eb, 4557877, c1b7072, 2835ccf, d6c8a03, a3d8591, 3b66154, 8a28715, 1a8d963, 7e6e2fc) |
| 03-01 | 178 | 3 | 3 (cos-docs) | 2 cos-docs (d8b9027, eb1611d) + 4 siblings (5da13fe, a62d33f, 06defae, f4a0b51) |
| 03-02 | 284 | 4 | 3 (cos-docs) + 2 (siblings, uncommitted per plan) | 3 cos-docs (5e174d1, 2a6c285, d519714) |
| 03-03 | 225 | 3 | 1 created + 3 modified (cos-docs) | 3 cos-docs (e2e291f, 879f6fc, 18c6973) |
| 04-01 | 260 | 3 | 4 created (cos-docs: Dockerfile, deploy/nginx.conf, .dockerignore, .gitignore) | 3 cos-docs (9f274b1, 1efc7ad, 0cef9d6) |
| 04-02 | 480 | 5 | 5 created (cos-docs kubernetes branch: k8s/namespace.yaml, k8s/deployment.yaml, k8s/service.yaml, k8s/kustomization.yaml, k8s/README.md) + 1 modified (04-02-PLAN.md on main) | 1 main (6875e05 port retarget) + 1 kubernetes (1646909 Kustomize bundle) |
| 04-03 | ~2700 | 3 | 3 created (scripts/emit-site-manifest.sh, scripts/install-runner.sh, .planning/phases/04-deploy-ci/RUNNER-SETUP.md) | 3 main (acc1d7b, 040926e, 3c9daa9) + host-side systemd install |

## Accumulated Context

### Validated Spikes (pre-roadmap, 2026-04-18)

1. `monorepo-plugin-aggregation` — `mkdocs-monorepo-plugin` with `!include` works for sibling-repo aggregation
2. `pydantic-mkdocstrings` — `mkdocstrings[python]` + `griffe-pydantic` renders Pydantic v2 trailing-string field docs natively
3. `mermaid-architecture-diagrams` — `pymdownx.superfences` + Material's bundled `mermaid.min.js` renders inline Mermaid (no extra plugin)
4. `talos-nginx-deploy` — Multi-stage Dockerfile + Kustomize → Talos NodePort pattern works (mirrors `quant-dashboard` deploy)

### Key Decisions Carried From PROJECT.md

- Use `!include` (NOT `!import`) — wrong directive fails silently
- Pin MkDocs Material + plugin versions explicitly (Material 2.0 will break plugins)
- Scaffold all ~25 repos in v1, not a pilot subset
- Per-repo `docs/` trees stay self-contained (no build-time deps imposed on sibling repos)

### Decisions From Plan 02-02

- Discovered 7 empirical PACKAGE_OVERRIDES beyond the 1 seeded (backend, cos_cie, mse, signal_bridge, edgar, src, ingest_shared) — all backported into scaffold-all.sh
- Discovered workspace-dep install failure mode: `pip install -e .` fails when local sibling packages (xuer-sgl, cos-sdl) are not on PyPI. Manual fix: `pip install --no-deps -e .` for COS-CIE and cos-signal-bridge. Wrapper automation deferred to future plan.
- scaffold.sh:emit_index_md template bug identified: unconditionally writes `- [API](api.md)` link even on docs-only repos, producing broken strict-build ref on COS-Infra and COS-Network. Fix deferred to Phase 3 (Phase 1 territory).
- `scaffold.sh`'s `write_user_owned` semantics confirmed: re-running with `--package <new>` does NOT overwrite existing `docs/api.md` (it's user-owned); manual delete required before re-scaffold or use `--force`. Not a bug — intentional per D-05 — but operationally important for PACKAGE_OVERRIDES backport workflow.
- Dirty-tree / non-main-branch repos (17 total) intentionally left for user triage per D-15/D-16 and plan's autonomous=false directive. Remediation per-repo documented in 02-ROLLOUT-STATUS.md.

### Decisions From Plan 02-01

- ROLLOUT_LIST encoded as a 30-entry bash array with EXCLUDE_LIST short-circuit at preflight (vs. trimming to 28) — preserves D-14 audit count exactly; FATAL guard verifies `${#ROLLOUT_LIST[@]} == 30` at script load
- PACKAGE_OVERRIDES seeded with only verified mismatch (COS-LangGraph→langgraph_agent); additional overrides discovered empirically when 02-02 first runs `mkdocs build --strict` across all 30 repos
- scaffold.sh `--package` warning on non-python repos is non-fatal so wrapper can pass it unconditionally based on overrides map (no per-repo type-aware branching needed at the wrapper layer)
- EXCLUDE_LIST and PACKAGE_OVERRIDES use `declare -A NAME=()` + per-key assignment (vs. inline `( [k]=v )`) so plan-spec verify regex `EXCLUDE_LIST\[cos-docs\]` matches exactly
- COS-Core deliberately omitted from ROLLOUT_LIST: it lacks its own `.git/`, lives in parent `/home/btc/github` repo; re-scaffold via direct `scaffold.sh /home/btc/github/COS-Core` only

### Decisions From Plan 01-02

- D-16 pin versions resolved at scaffold-time from PyPI (mkdocs-material 9.7.6 — NOT 1.6.1 from CONTEXT.md, which conflated mkdocs-material with mkdocs core)
- mkdocstrings handler MUST include `extensions: [griffe_pydantic]` AND `show_submodules: true` to render Pydantic v2 field-level docstrings (neither auto-loads in mkdocstrings 1.0.x); both auto-added during E2E smoke after grep for field docstring substring failed initially
- emit_mkdocs_yml takes `(site_name, repo_type)` so the `- API: api.md` nav line is conditional via a shell `echo` between two heredocs (D-11)
- Distinct heredoc terminators (REQS_EOF, INDEX_EOF, ARCHITECTURE_EOF, API_EOF, MKDOCS_EOF, MKDOCS_PLUGINS_EOF) used per emit function to avoid past EOF/EOF collision risk

### Decisions From Plan 01-01

- scaffold.sh uses `sed -nE` (POSIX) for TOML `[project].name` extraction rather than GNU awk — keeps zero-dep promise on any workstation
- D-13 hyphen→underscore normalization is a single bash parameter expansion (`${raw_name//-/_}`) at scaffold.sh:107, applied uniformly to BOTH the pyproject path AND the basename-fallback path
- Empty-diff suppression implemented by capturing `diff -u` output to a variable and gating printf on `[ -n "$diff_out" ]` — single branch, no separate `cmp` pre-check
- Atomic write pattern (`${path}.tmp.$$` → `mv`) reuses workspace's Python `tmp → rename` convention in bash

### Decisions From Plan 03-01

- Aggregator venv pins are 4 lines, deliberately excluding mkdocstrings + griffe-pydantic (D-01 upheld per upstream mkdocs-monorepo-plugin #73: child `plugins:` blocks are not executed by parent build)
- 29-repo nav locked under 8 domain groups (Forges/Signal Stack/Agent/Presentation/Warehouse/Network/Schema/Infrastructure); quant-dashboard-k8s-deployment dropped after disk-presence verification
- Placeholder `docs/index.md` shipped in 03-01; full repo-index + domain overviews deferred to 03-03
- Comment hygiene rule: comment prose in aggregator config files must avoid naming excluded packages literally (prose like "API-rendering deps" keeps `! grep -q mkdocstrings` gates green without semantic loss)
- Cherry-pick-with-dirty-tree precedent: `git stash push -u` + cherry-pick + `git stash pop` is safe when scaffold has zero file-path overlap with WIP; used for quant-dashboard kubernetes branch

### Decisions From Plan 03-02

- API-02 + API-03 closed: build-all-api.sh pre-renders all 20 Python sibling repos via isolated `uv venv .venv-docs`; aggregator consumes Material HTML via `<div class="cos-docs-prerendered-api" markdown="0">` passthrough (md_in_html). Mega-venv formally rejected; PROJECT.md "Defer API-docs strategy" Pending row resolved with evidence citation (xuer-sgl / cos-sdl workspace-dep evidence from 02-02-SUMMARY.md).
- BTC-Forge + COS-MSE docstring hygiene fixes landed uncommitted on their `main` branches per plan Task 0 Step B directive (sibling-repo commits are user/automation territory, same as Phase 2 rollout pattern).
- NO_DEPS_INSTALL map remains at 2 entries (COS-CIE, cos-signal-bridge) — no new empirical additions surfaced during Task 2.
- md_in_html strips `markdown="0"` at render time but preserves the enclosing `<div class="cos-docs-prerendered-api" markdown="0">` tag verbatim — the class attribute is the durable passthrough proof (verified 20/20 in final aggregator `site/`).

### Decisions From Plan 03-03

- AGGR-03 + DIAG-03 closed: workspace Mermaid (flowchart LR, 8 domain subgraphs + 1 EXT context subgraph, exactly 6 critical data arrows per D-13) + 29-row repo index landing page + Architecture nav entry shipped; aggregator `mkdocs build --strict` exits 0 with Mermaid rendered as `<pre class="mermaid">` in `site/architecture/index.html`, 20/20 API pages populated, and all 8 domain labels present in left-nav.
- Architecture page takes nav slot 2 (between Overview and Forges) so workspace orientation precedes any per-repo group.
- Informational `<repo>/architecture/` link notes from MkDocs are INFO-level (not WARNING) and do not block `--strict`; non-blocking tidy-up available for Phase 4 if fully clean `--strict -v` output is desired.

### Decisions From Plan 04-01

- Multi-stage label (`FROM nginx:1.27-alpine AS runtime`) retained for workspace convention even though there is no separate builder stage — site/ is built outside Docker on the runner filesystem (RESEARCH §4 Pitfall 2). Preserves option to add a future transform stage without restructuring.
- cos-docs's first `.gitignore` introduced to block site/, site-manifest.json, .venv-aggr-local/, .venv-agg/ — before this commit the repo had no gitignore at all, so smoke-test artifacts were only safe by convention.
- Dropped `text/html` from nginx gzip_types (Rule 1 fix): base nginx config already includes it and duplicating emits a warning on every startup. Behavior unchanged; log bar is now clean.
- Smoke-test wrapper pattern: `set +e; trap restore EXIT` around build-all-api.sh --keep / mkdocs build / docker build, plus an early --restore before docker build. Guarantees sibling repos revert even on mid-pipeline abort. Same pattern recommended for Plan 04-04 CI workflow (keeps the on-disk workspace clean for the next run).
- Build-context bound verified empirically: docker build transferred 31.48MB (vs. multi-GB if `/home/btc/github/` leaked in). `.dockerignore` is the only structural gate — it must not regress.

### Decisions From Plan 04-03

- gh auth scope requirement relaxed from `admin:repo_hook` → `repo` (in-flight Rule-2 fix, commit `3c9daa9`). GitHub's runner-registration-token API requires only `repo`; `admin:repo_hook` governs webhook admin and was an over-strict inheritance from the 04-CONTEXT user_setup block. Standard `gh auth login` default scopes (`repo,workflow,gist,read:org`) now satisfy install-runner.sh preflight — no `gh auth refresh` round trip needed.
- Runner registered as `talos-cos-docs` with labels `self-hosted,cos-docs,talos` on 10.70.0.102 as user `btc`; systemd unit `actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` active. Runner version 2.333.1.
- Runner work-dir isolation confirmed: `/home/btc/actions-runner/_work/` distinct from `/home/btc/github/cos-docs/` — CI will not pollute the docs source tree.
- CI-01/02/03 remain Pending in REQUIREMENTS.md despite 04-03 completion. This plan delivers infra only; satisfaction requires the Plan 04-04 workflow (nightly/push/dispatch triggers) and Plan 04-05 E2E registry push verification.
- `emit-site-manifest.sh` discovers 31 sibling repos in `/home/btc/github/` (exceeds the plan's >=25 threshold), excludes cos-docs, emits 40-hex `cos_docs_sha` + ISO-8601 `generated_at` + jq-built `repos` map.

### Decisions From Plan 04-02

- NodePort retarget cascade: 30081 (held by pricefeed) → 30082 (held by xuer-operator) → **30083 (free, verified via live-cluster enumeration)**. Governance artifacts (REQUIREMENTS DEPLOY-02/DEPLOY-04, ROADMAP, 04-CONTEXT.md) updated pre-executor in commit fbc65b7; plan-only retarget in 6875e05.
- `kubernetes` branch branched from `main` (not orphan) per D-08 — matches quant-dashboard workspace precedent. Dockerfile + mkdocs.yml inherited but unused for `kubectl apply -k`.
- `commonLabels` retained in kustomization.yaml despite kustomize v5 deprecation warning — preserves plan fidelity and matches workspace precedent; deferred as tech-debt item for potential v6 migration.
- No `imagePullSecrets` — registry 10.70.0.30:5000 is on the Talos containerd `insecure-registries` list (anonymous pull). `imagePullPolicy: Always` on `:latest` guarantees rollout-restart fetches fresh digests.
- containerPort 8080 ↔ Dockerfile EXPOSE 8080 lockstep contract documented in `k8s/README.md` so cross-branch port changes cannot drift silently.
- Server-side dry-run workflow: `kubectl apply -f namespace.yaml` → `kubectl apply -k k8s/ --dry-run=server` → `kubectl delete namespace cos-docs`. Bundle admission-validated clean against live Talos cluster.

### Open Decisions

- **API-02**: RESOLVED by 03-02 (commit d519714 in cos-docs) — PROJECT.md Key Decision row "API-docs Strategy" added with full evidence trail.
- **AGGR-03 / DIAG-03**: RESOLVED by 03-03 — workspace Mermaid + repo-index landing page shipped; Phase 3 fully closed.
- **DEPLOY-01**: RESOLVED by 04-01 (9f274b1 + 1efc7ad + 0cef9d6) — Dockerfile + nginx.conf + .dockerignore shipped with 4/4 local curl smoke assertions green.
- **DEPLOY-02 / DEPLOY-03**: RESOLVED by 04-02 (1646909 on `kubernetes` branch) — Kustomize bundle rendered and server-side dry-run PASSED; NodePort 30083 locked.
- **DEPLOY-04 (partial)**: artifacts ready; actual `kubectl apply -k` + reachability curl deferred to 04-05.
- **CI-01 / CI-02 / CI-03 (partial — infra only)**: self-hosted runner live + `emit-site-manifest.sh` shipped (04-03, commits `acc1d7b`, `040926e`, `3c9daa9`). Workflow authoring deferred to 04-04; registry-push verification deferred to 04-05. Requirements remain Pending in REQUIREMENTS.md.

### Todos

- (none yet)

### Blockers

- (none)

## Session Continuity

**Last session:** 2026-04-20T14:50:00Z
**Next action:** Phase 4 plan 04-03 complete (self-hosted runner live on 10.70.0.102 + emit-site-manifest.sh + install-runner.sh + RUNNER-SETUP.md on main @ acc1d7b, 040926e, 3c9daa9). Next up: 04-04 (`.github/workflows/build.yml`: nightly + push + dispatch, in-place git sync, build-all-api --keep, strict-fail + allow_partial, if:always() restore, multi-tag push, rollout hint). No blockers.
**Files in play:**

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

---
*State initialized: 2026-04-18*
