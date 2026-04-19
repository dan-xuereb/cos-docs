---
phase: 01-scaffold-template
plan: 02
subsystem: infra
tags: [mkdocs, mermaid, pydantic, templates, griffe-pydantic]

requires:
  - phase: 01-scaffold-template
    plan: 01
    provides: scaffold.sh skeleton with placeholder emit_* functions
provides:
  - Concrete heredoc template bodies for all 5 emit_* functions
  - PyPI-resolved D-16 pin versions (mkdocs-material 9.7.6, mkdocs-monorepo-plugin 1.1.2, mkdocstrings[python] 1.0.4, griffe-pydantic 1.3.1)
  - mkdocs.yml template with pymdownx.superfences Mermaid custom_fence (D-17)
  - mkdocstrings handler with griffe_pydantic extension and show_submodules (API-01 wiring)
  - emit_mkdocs_yml accepts (site_name, repo_type) so api.md nav line is conditional (D-11)
  - End-to-end verified scaffold against COS-Core: mkdocs build --strict produces site with rendered Mermaid AND Pydantic field docstrings
affects: [02-content-migration]

tech-stack:
  added:
    - mkdocs-material==9.7.6
    - mkdocs-monorepo-plugin==1.1.2
    - mkdocstrings[python]==1.0.4
    - griffe-pydantic==1.3.1
  patterns:
    - "Quoted vs unquoted heredocs chosen per emit function based on whether shell interpolation is needed"
    - "Single distinct terminator per heredoc (REQS_EOF, MKDOCS_EOF, MKDOCS_PLUGINS_EOF, INDEX_EOF, ARCHITECTURE_EOF, API_EOF) avoids past EOF/EOF collision risk"
    - "Conditional shell echo line between two heredocs to inject python-only nav entry without forking the entire YAML body"

key-files:
  created:
    - .planning/phases/01-scaffold-template/01-02-SUMMARY.md
  modified:
    - cos-docs/scripts/scaffold.sh

key-decisions:
  - "D-16 pin versions resolved at scaffold-time from PyPI (not the literal 1.6.1 from CONTEXT.md, which conflated mkdocs-material with mkdocs core); mkdocs-material 9.7.6 baked into emit_requirements_docs_txt"
  - "mkdocstrings handler requires both extensions: [griffe_pydantic] and show_submodules: true to render Pydantic v2 field-level docstrings — neither is on by default in mkdocstrings 1.0.x; both auto-added per Rules 1+2 after E2E smoke proved their absence"
  - "emit_mkdocs_yml split into two cat heredocs around a conditional `echo \"  - API: api.md\"` so the python-only nav line stays inline with the rest of the nav block"

requirements-completed: [SCAF-02, SCAF-03, DIAG-01, API-01]

metrics:
  duration: ~25min
  completed: 2026-04-19
  tasks: 3
  files: 1
---

# Phase 1 Plan 2: Concrete Template Bodies + E2E Smoke Summary

**Replaced placeholder emit_* heredoc bodies in scaffold.sh with concrete, pinned, Mermaid-aware, Pydantic-aware templates; resolved D-16 pin versions from PyPI; verified the full pipeline end-to-end against COS-Core with `mkdocs build --strict` rendering Mermaid SVG containers AND Pydantic v2 trailing-string field docstrings.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-18 (this session)
- **Tasks:** 3
- **Files modified:** 1 (`cos-docs/scripts/scaffold.sh`)

## Accomplishments

- `emit_requirements_docs_txt` now emits 4 PyPI-resolved D-16 pins (single-quoted REQS_EOF heredoc, no interpolation).
- `emit_index_md` emits user-owned overview template (single-quoted INDEX_EOF heredoc).
- `emit_architecture_md` emits a sample Mermaid `flowchart LR` diagram inside a triple-backtick `mermaid` fence (single-quoted ARCHITECTURE_EOF heredoc — backticks don't need escaping).
- `emit_api_md` emits the `::: ${pkg}` mkdocstrings autodoc directive with D-14 options (unquoted API_EOF heredoc; backticks around `griffe-pydantic` literal escaped).
- `emit_mkdocs_yml` accepts `(site_name, repo_type)` and emits Material theme, conditional API nav line, mkdocstrings plugin (with griffe_pydantic + show_submodules), and pymdownx.superfences Mermaid custom_fence per D-17 (split unquoted MKDOCS_EOF + single-quoted MKDOCS_PLUGINS_EOF).
- `main()` call site updated to pass both `$site_name` and `$repo_type` to `emit_mkdocs_yml`.

## Task Commits

1. **Task 0: Resolve D-16 pin versions from PyPI + bake into emit_requirements_docs_txt** — `350edac` (feat)
2. **Task 1: Populate remaining emit_* heredoc bodies + main() call site** — `287564a` (feat)
3. **Task 2: E2E smoke test fix — enable griffe_pydantic + show_submodules** — `ded6955` (fix; Rule 1 + Rule 2 deviation)

## D-16 Pin Resolution (developer-facing note)

CONTEXT.md D-16 listed `mkdocs-material==1.6.1` which **appears to conflate mkdocs-material (currently 9.x) with mkdocs core (currently 1.6.x)**. Resolved versions from PyPI at scaffold-time via `pip install --dry-run --report` against a clean venv:

```
mkdocs-material: 9.7.6 (CONTEXT.md D-16 listed 1.6.1, which appears to conflate with mkdocs core)
mkdocs-monorepo-plugin: 1.1.2
mkdocstrings[python]: 1.0.4
griffe-pydantic: 1.3.1
```

**Recommendation:** Update CONTEXT.md D-16 to either (a) remove literal versions and treat as "pin these four packages with `==`", or (b) refresh the literal `mkdocs-material==1.6.1` to a current 9.x value. The Phase 2 content-migration agents will read CONTEXT.md and may otherwise re-introduce the wrong pin.

Sanity-checked: mkdocs-material 9.7.6 passes the "not 1.x or 2.x" guard (Task 0 step 2). Pip install in a fresh venv succeeded for all 4 pins.

## Requirements Mapping (CONTEXT.md decision → scaffold.sh location)

| Decision | scaffold.sh symbol | Lines (approx) |
|----------|--------------------|----------------|
| D-12 (mkdocstrings ::: block) | `emit_api_md`, `::: ${pkg}` | ~135 |
| D-14 (show_root_heading + members_order) | `emit_api_md` (api.md), `emit_mkdocs_yml` (handler block) | ~138, ~196 |
| D-15 (per-repo requirements-docs.txt) | `emit_requirements_docs_txt` + `write_scaffold_owned "requirements-docs.txt"` in main() | ~210, ~228 |
| D-16 (4 pinned packages) | `emit_requirements_docs_txt` heredoc | ~210-216 |
| D-17 (pymdownx.superfences Mermaid custom_fence) | `emit_mkdocs_yml` MKDOCS_PLUGINS_EOF block | ~201-205 |
| D-11 (TS/docs-only repos skip api.md nav) | conditional `echo "  - API: api.md"` between MKDOCS_EOF and MKDOCS_PLUGINS_EOF | ~184-186 |

## E2E Smoke Test Results (vs COS-Core)

Setup: `mktemp -d` tempdir copy of `/home/btc/github/COS-Core/{pyproject.toml,src}`, fresh venv, `pip install -r requirements-docs.txt && pip install -e . && mkdocs build --strict`.

| Step | Result | Notes |
|------|--------|-------|
| scaffold.sh runs against COS-Core tempdir | PASS | All 5 files written |
| `grep '^::: cos_core$' docs/api.md` | PASS | Underscore form (D-13 normalization) |
| `grep '^::: cos-core$' docs/api.md` | PASS (absent) | No hyphenated form |
| `pip install -r requirements-docs.txt` | PASS | All 4 pins install cleanly in Python 3.12 venv |
| `pip install -e .` (COS-Core) | PASS | |
| `mkdocs build --strict` | PASS | `Documentation built in 0.84 seconds`, no warnings (only the unrelated mkdocs-material team's mkdocs-2.0 advisory banner, which is informational) |
| Mermaid grep on architecture page (DIAG-01) | **PASS** | `class="mermaid"` present 1× in `site/architecture/index.html` |
| Field-docstring grep on api page (API-01) | **PASS** | `Lowercase exchange name` (the OHLCVBar.exchange field docstring from `/home/btc/github/COS-Core/src/cos_core/models/market.py:16`) present 4× in `site/api/index.html` |

Build log: `/tmp/mkdocs-build-final.log` (transient — cleaned up post-test).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1+2 — Bug + Critical functionality] mkdocstrings template missing griffe_pydantic extension and show_submodules**

- **Found during:** Task 2 E2E smoke
- **Issue:** With the original template (D-14 minimal options block only), `mkdocs build --strict` succeeded but the rendered `site/api/index.html` contained zero occurrences of `Lowercase exchange name`. Investigation revealed two distinct missing pieces:
  1. **`extensions: [griffe_pydantic]`** — mkdocstrings 1.0.x does NOT auto-load the griffe-pydantic extension just because the package is installed. Without explicit registration, Pydantic field labels (`pydantic-field`) render but trailing-string field docstrings are dropped.
  2. **`show_submodules: true`** — mkdocstrings only walks `cos_core` itself by default; reexports from submodules (e.g. `cos_core.models.market.OHLCVBar`) are surfaced as autoref links but not rendered with their own headings or field details. Without this, even with griffe-pydantic active, OHLCVBar fields never get a render block.
- **Fix:** Added both lines to `emit_mkdocs_yml`'s mkdocstrings handler options block. After fix, `Lowercase exchange name` appears 4× in built HTML. This is a Rule 1 (template bug — template didn't actually do what it claimed) AND Rule 2 (critical functionality — API-01 acceptance requires field-level rendering, not just class-name presence) auto-fix.
- **Files modified:** `cos-docs/scripts/scaffold.sh`
- **Commit:** `ded6955`
- **Plan implication:** Plan 02 source spec (D-14, plus implicit "and griffe-pydantic should just work") was incomplete. Future API-docs work in Phase 3 should keep this config; if the API-02 mega-venv-vs-pre-rendered decision flips to per-repo CI, the same handler config must be carried into the per-repo build step.

## Authentication Gates

None — no external auth required for PyPI install or mkdocs build.

## Open Items for Next Phase

- Phase 1 ROADMAP success criteria 1-5 are now demonstrable end-to-end against any Python repo with Pydantic v2 trailing-string field docstrings. Phase 2 (Content Migration) is unblocked.
- The `--force` smoke from Plan 01-01 plus the mkdocs build smoke from Plan 01-02 cover both ownership semantics and template correctness; no further Phase 1 work is required.
- API-02 (mega-venv vs pre-rendered per-repo CI) remains a Phase 3 decision; the per-repo `requirements-docs.txt` works for both options.

## Phase 1 Success Criteria Verification

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | scaffold.sh creates docs/index.md, docs/architecture.md, docs/api.md, mkdocs.yml, requirements-docs.txt | PASS | Plan 01-01 smoke + Plan 01-02 E2E smoke both verified |
| 2 | mkdocs serve previews with no missing-plugin errors | PASS | `mkdocs build --strict` (stricter than serve) exits 0 |
| 3 | Mermaid renders as SVG | PASS | `class="mermaid"` container present in built HTML; Material loads bundled mermaid.min.js client-side |
| 4 | Pydantic v2 field docstrings render natively | PASS | Field docstring substring `Lowercase exchange name` (OHLCVBar.exchange) renders 4× in built api page |
| 5 | Re-running does not clobber edited docs/*.md | PASS | Plan 01-01 smoke case 4 verified |

## Self-Check: PASSED

- File `/home/btc/github/cos-docs/scripts/scaffold.sh` exists and is executable.
- Commits exist on main: `350edac` (Task 0), `287564a` (Task 1), `ded6955` (Task 2 fix).
- E2E smoke against COS-Core executed successfully end-to-end this session; output captured above.
- All 5 emit_* functions have non-placeholder bodies (`grep -q TODO scaffold.sh` returns no match).

---
*Phase: 01-scaffold-template*
*Completed: 2026-04-18*
