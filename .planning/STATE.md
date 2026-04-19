---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-04-18T00:00:00.000Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 25
---

# State: cos-docs

**Initialized:** 2026-04-18

## Project Reference

**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

**Current Focus:** Phase 1 — Scaffold & Template

## Current Position

Phase: 1 (Scaffold & Template) — COMPLETE
Plan: 2 of 2 — complete

- **Phase:** 1 — Scaffold & Template (Complete)
- **Plan:** 01-01 (32a5cf5); 01-02 (350edac, 287564a, ded6955) complete
- **Status:** Phase 1 complete; ready for Phase 2 (Content Migration)
- **Progress:** [■□□□] 1/4 phases complete (2/2 plans of phase 1)

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases planned | 4 |
| Phases complete | 1 |
| Plans complete | 2 |
| v1 requirements mapped | 26/26 |
| Spikes completed | 4 (all ✓ VALIDATED) |

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

**Last session:** 2026-04-18 — Plan 01-02 executed: emit_* heredoc bodies populated (Mermaid superfences, mkdocstrings ::: block, pinned requirements with PyPI-resolved D-16 versions); E2E smoke against COS-Core verified Mermaid rendering AND Pydantic v2 field docstring rendering in built site (`Lowercase exchange name` from OHLCVBar.exchange found 4× in api/index.html). Auto-fixed missing griffe_pydantic extension + show_submodules in mkdocstrings handler config.
**Next action:** Phase 1 complete. Begin Phase 2 (Content Migration) — scaffold all ~25 sibling repos, migrate README/CLAUDE.md content into docs/ trees.
**Files in play:**

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/config.json`

---
*State initialized: 2026-04-18*
