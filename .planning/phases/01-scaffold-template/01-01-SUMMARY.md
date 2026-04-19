---
phase: 01-scaffold-template
plan: 01
subsystem: infra
tags: [bash, scaffold, mkdocs, idempotency]

requires:
  - phase: 00-init
    provides: PROJECT.md, REQUIREMENTS.md (SCAF-01..04), CONTEXT.md (D-01..D-17)
provides:
  - Pure-bash scaffold.sh skeleton with full control flow
  - Repo-type auto-detection (python > ts > docs-only)
  - Python package-name extraction with hyphen->underscore normalization (D-13)
  - File-ownership routing (user-owned vs scaffold-owned)
  - Atomic tmp->mv writes with diff-on-overwrite + empty-diff suppression
  - Placeholder emit_* functions ready for Plan 02 to replace
affects: [01-02-template-bodies, 02-content-migration]

tech-stack:
  added: [bash >=4.0, sed (POSIX), diff -u]
  patterns:
    - "set -euo pipefail strict mode (matches workspace bash style)"
    - "Atomic file writes: tmp.$$ -> mv (analog of CLAUDE.md Python atomic-write convention)"
    - "Two-tier file ownership (user-owned vs scaffold-owned) with diff-on-overwrite"
    - "Single-file self-contained scaffold (no separate templates/ dir)"

key-files:
  created:
    - cos-docs/scripts/scaffold.sh
  modified: []

key-decisions:
  - "Used sed -nE range over GNU awk for [project].name extraction — portable across awk variants without requiring gawk"
  - "Empty-diff suppression implemented by capturing diff output to a variable and checking length before printing — single branch, no separate sentinel"
  - "Hyphen->underscore normalization placed in detect_python_package() so it applies uniformly to BOTH the pyproject and basename-fallback paths (one line: pkg_name=\"\\${raw_name//-/_}\")"

patterns-established:
  - "emit_* function contract: each emit takes its dynamic args (e.g. site_name, package_name) and writes the full file body to stdout. Plan 02 swaps echo placeholders for heredoc bodies without touching call sites."
  - "write_user_owned vs write_scaffold_owned wrappers centralize the existence/diff/atomic-write policy so emit functions stay pure."

requirements-completed: [SCAF-01, SCAF-04]

duration: ~12min
completed: 2026-04-19
---

# Phase 1 Plan 1: Scaffold Tool Skeleton Summary

**Pure-bash scaffold.sh skeleton with arg parsing, repo-type auto-detection, hyphen-normalized Python package extraction, and atomic two-tier file-ownership writes — ready for Plan 02 to drop in heredoc template bodies.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-19T07:22Z
- **Completed:** 2026-04-19T07:34Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- `cos-docs/scripts/scaffold.sh` (221 lines, executable, `bash -n` clean) implements the full control flow for D-01, D-03, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-13.
- Hyphen→underscore normalization (D-13) applied uniformly to both the `[project].name` path and the directory-basename fallback at `scripts/scaffold.sh:107` inside `detect_python_package()`.
- Empty-diff suppression (D-06 refinement) verified end-to-end — re-running scaffold on an unchanged target produces zero diff output on stderr.
- Smoke harness exercised all 7 sub-cases against real workspace repos (`COS-Core/pyproject.toml`, `quant-dashboard/package.json`).

## Task Commits

1. **Task 1: scaffold.sh skeleton** — `32a5cf5` (feat)
2. **Task 2: Smoke verification (no edits)** — verification-only, no commit

## Files Created/Modified

- `cos-docs/scripts/scaffold.sh` — created. Pure-bash, single file, executable. Sections: shebang+strict mode, top-of-file usage comment, arg parser, `detect_repo_type()`, `detect_python_package()` (D-13 normalization at line 107), 5 placeholder `emit_*` functions, `write_user_owned()` / `write_scaffold_owned()` helpers, `main()` orchestrator.

## Decisions Made

- **sed over gawk** for TOML `[project].name` extraction — keeps the dependency surface to POSIX tools so the script runs on any workstation/CI without `apt install gawk`.
- **Atomic write pattern** (`${path}.tmp.$$` → `mv`) matches the workspace's Python `tmp → rename` convention (per `/home/btc/github/CLAUDE.md` "Error Handling — Atomic file writes"), reapplied here in bash.
- **Single-branch empty-diff suppression** — capture `diff -u` output into a shell variable, gate the `printf` on `[ -n "$diff_out" ]`. No separate `cmp` pre-check needed.

## Deviations from Plan

None — plan executed exactly as written. The plan offered both a GNU awk and a `sed -nE` snippet for TOML parsing; I selected the sed variant for portability per the planner's allowance.

## D-13 Normalization Location

- **File:** `cos-docs/scripts/scaffold.sh`
- **Function:** `detect_python_package()`
- **Line:** 107 — `local pkg_name="${raw_name//-/_}"`
- **Coverage:** Applies AFTER the pyproject parse OR the basename fallback assignment to `raw_name`, so both code paths are normalized through a single bash parameter expansion. Smoke case 1 confirmed `cos-core` (in COS-Core's pyproject) → `cos_core` in the generated `docs/api.md`.

## Smoke Test Results (7 sub-cases)

| # | Case                              | Result | Notes |
|---|-----------------------------------|--------|-------|
| 1 | Python repo (COS-Core pyproject)  | PASS   | api.md generated; contains `cos_core`, NOT `cos-core` |
| 2 | TS repo (quant-dashboard package.json) | PASS | api.md correctly absent |
| 3 | Docs-only (empty dir)             | PASS   | api.md correctly absent |
| 4 | Idempotency (no --force)          | PASS   | Hand-edited `docs/index.md` survived re-run; `[skip]` lines emitted |
| 5 | --force overwrite                 | PASS   | Hand-edited `docs/index.md` overwritten |
| 6 | Diff-on-overwrite (mkdocs.yml)    | PASS   | Unified diff with `---`/`+++` headers + `-`/`+` body printed to stderr |
| 7 | **Empty-diff suppression**        | PASS   | Re-run on unchanged scaffold produced ZERO `---` or `+++` lines on stderr |

All 7 cases passed; smoke harness emitted `SMOKE OK`.

## Issues Encountered

None.

## Open Items for Plan 02

- Replace `emit_index_md`, `emit_architecture_md`, `emit_api_md`, `emit_mkdocs_yml`, `emit_requirements_docs_txt` placeholder bodies with real heredoc templates.
- `emit_mkdocs_yml` will likely need a 2nd argument (REPO_TYPE) so the python-only `mkdocstrings` plugin block can be conditionally included; the current signature only takes `site_name`. Plan 02 should adjust both the function and the `main()` call site.
- Templates must include `pymdownx.superfences` Mermaid `custom_fence` config (D-17) and the four pinned plugin versions (D-15, D-16): `mkdocs-material==1.6.1`, `mkdocs-monorepo-plugin`, `mkdocstrings[python]`, `griffe-pydantic`.
- `docs/api.md` template must include `::: <package_name>` mkdocstrings directive (D-12) plus the minimal options block from D-14 (`show_root_heading: true`, `members_order: alphabetical`).
- Add the smoke test as a permanent test fixture (planner discretion from CONTEXT.md "Claude's Discretion") if Plan 02 ships it.

## Next Phase Readiness

- Plan 01-02 unblocked. Control flow is locked; template work is purely additive inside the emit functions.
- Phase 2 (content migration) still gated on Plan 01-02 completion.

## Self-Check: PASSED

- File `cos-docs/scripts/scaffold.sh` exists and is executable: confirmed via `bash -n` + `[ -x ]`.
- Commit `32a5cf5` exists in `git log` on branch `main`.
- All 7 smoke sub-cases passed (output captured during Task 2 execution).
- D-13 normalization verified end-to-end (`cos-core` → `cos_core` in generated api.md).

---
*Phase: 01-scaffold-template*
*Completed: 2026-04-19*
