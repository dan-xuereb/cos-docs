---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-04-19T19:23:48.000Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 5
  completed_plans: 3
  percent: 35
---

# State: cos-docs

**Initialized:** 2026-04-18

## Project Reference

**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

**Current Focus:** Phase 1 — Scaffold & Template

## Current Position

Phase: 2 (Content Migration) — IN PROGRESS
Plan: 1 of 3 — complete

- **Phase:** 2 — Content Migration (Wave 1 of 3 complete)
- **Plan:** 02-01 (63b2246, 78c5101) complete; ready for 02-02 (rollout sweep)
- **Status:** Rollout tooling shipped; ready for plan 02-02 (full sweep + triage)
- **Progress:** [■■□□] 1/4 phases complete + 1/3 plans of phase 2

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases planned | 4 |
| Phases complete | 1 |
| Plans complete | 3 |
| v1 requirements mapped | 26/26 |
| Spikes completed | 4 (all ✓ VALIDATED) |

| Plan | Duration (s) | Tasks | Files | Commits |
|------|--------------|-------|-------|---------|
| 02-01 | 276 | 2 | 2 | 2 (63b2246, 78c5101) |

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

**Last session:** 2026-04-19 — Executed plan 02-01 (rollout tooling). Two commits: 63b2246 (scaffold.sh `--package <name>` flag, D-17) and 78c5101 (scaffold-all.sh wrapper, D-01..D-17). ROLLOUT_LIST = 30 entries (D-14 audit, FATAL guard); EXCLUDE_LIST = 2 (cos-docs, capability-gated-agent-architecture); DIAGRAM_EXEMPT = 3 (Hardware, Network, CGAA); PACKAGE_OVERRIDES = 1 seeded (COS-LangGraph→langgraph_agent). All plan-spec verify greps pass; anti-regression confirmed (Phase 1 COS-Core fallback path produces `::: cos_core` unchanged). Optional dry-run skipped — full sweep is the deliverable of plan 02-02.
**Next action:** Execute Phase 2 wave 2 — plan 02-02 (rollout sweep, failure triage, REQUIREMENTS.md DIAG-02 amendment, workspace CLAUDE.md project-map update). `autonomous: false` — needs human judgment for failure triage.
**Files in play:**

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

---
*State initialized: 2026-04-18*
