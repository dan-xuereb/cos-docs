---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-04-20T05:19:26.384Z"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 8
  completed_plans: 5
  percent: 63
---

# State: cos-docs

**Initialized:** 2026-04-18

## Project Reference

**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

**Current Focus:** Phase 1 — Scaffold & Template

## Current Position

Phase: 2 (Content Migration) — IN PROGRESS
Plan: 2 of 3 — complete

- **Phase:** 2 — Content Migration (Wave 2 of 3 complete)
- **Plan:** 02-02 (d8cffe6 in cos-docs + 83683eb in parent + 9 sibling-repo scaffold commits) complete; ready for 02-03 (per-repo content authoring)
- **Status:** Ready to execute
- **Progress:** [■■■□] 1/4 phases complete + 2/3 plans of phase 2

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

### Open Decisions

- **API-02**: API-docs strategy (mega-venv vs pre-rendered per-repo CI) — must be decided in Phase 3 before Phase 4 (Deploy)

### Todos

- (none yet)

### Blockers

- (none)

## Session Continuity

**Last session:** 2026-04-20T04:49:30.160Z
**Next action:** Per-repo triage (user): clean 13 dirty trees, checkout main on 4 kubernetes branches, then re-run `scaffold.sh /path/to/repo` per-repo. Separately, execute Phase 2 wave 3 — plan 02-03 (per-repo content authoring). Consider scoping a scaffold.sh template-bug fix (emit_index_md repo_type awareness) and a `NO_DEPS_INSTALL` wrapper enhancement as follow-up work.
**Files in play:**

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

---
*State initialized: 2026-04-18*
