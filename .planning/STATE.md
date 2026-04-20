---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-04-20T05:36:00.000Z"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 8
  completed_plans: 7
  percent: 88
---

# State: cos-docs

**Initialized:** 2026-04-18

## Project Reference

**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

**Current Focus:** Phase 1 — Scaffold & Template

## Current Position

Phase: 3 (Aggregator & API Strategy) — IN PROGRESS
Plan: 2 of 3 — complete

- **Phase:** 3 — Aggregator & API Strategy (Wave 2 of 3 complete)
- **Plan:** 03-02 (5e174d1 + 2a6c285 + d519714 in cos-docs) complete; ready for 03-03 (workspace Mermaid + top-level index.md / architecture.md)
- **Status:** Ready to execute 03-03
- **Progress:** [■■■□] 2/4 phases complete + 2/3 plans of phase 3; build-all-api.sh 20/20 OK; aggregator strict build exits 0 with pre-rendered API pages for all 20 Python repos

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

### Open Decisions

- **API-02**: RESOLVED by 03-02 (commit d519714 in cos-docs) — PROJECT.md Key Decision row "API-docs Strategy" added with full evidence trail.

### Todos

- (none yet)

### Blockers

- (none)

## Session Continuity

**Last session:** 2026-04-20T05:36:00.000Z
**Next action:** Execute Plan 03-03 (workspace Mermaid data-flow diagram + top-level docs/index.md repo-index table + docs/architecture.md narrative) — the final Wave of Phase 3. build-all-api.sh is proven 20/20 OK and the aggregator strict-build exits 0 with real API pages. 03-03 adds the workspace-overview layer (AGGR-03, DIAG-03) on top of the now-populated nav.
**Files in play:**

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

---
*State initialized: 2026-04-18*
