---
phase: 03-aggregator-api-strategy
plan: 02
subsystem: api-pre-render
tags: [api-docs, mkdocstrings, pre-render, isolated-venv, md-in-html-passthrough]
requires: [aggregator-mkdocs-yml, per-repo-mkdocs-yml-scaffold]
provides: [build-all-api-sh, pre-rendered-api-pages, api-02-decision-recorded]
affects: [cos-docs, 20-python-sibling-repos, PROJECT.md-key-decisions]
tech_added: []
patterns:
  - per-repo-isolated-venv-via-uv
  - md-in-html-passthrough-with-markdown-zero
  - swap-in-place-with-backup-and-restore
  - greppable-repo-status-accumulator
  - atomic-tmp-rename-write
key_files_created:
  - cos-docs/scripts/build-all-api.sh
  - cos-docs/.build-all-api-status.md
  - cos-docs/.planning/phases/03-aggregator-api-strategy/03-02-SUMMARY.md
key_files_modified:
  - cos-docs/.planning/PROJECT.md
  - BTC-Forge/src/api.py (uncommitted — sibling-repo diff on main, per plan Task 0 Step B directive)
  - COS-MSE/src/mse/regimes/smoothing.py (uncommitted — sibling-repo diff on main)
decisions:
  - "API-02 resolved: pre-rendered per-repo via isolated .venv-docs (mega-venv formally rejected; evidence = xuer-sgl / cos-sdl not on PyPI)"
  - "md_in_html passthrough with class='cos-docs-prerendered-api' markdown='0' is the cross-renderer seam between per-repo Material HTML and aggregator nav composition"
  - "Swap-in-place pattern (backup + restore) keeps sibling-repo git history free of rendered artifacts; Phase 4 CI will wrap the per-repo loop body, not replace it"
  - "BTC-Forge + COS-MSE docstring fixes land uncommitted on main per plan Task 0 Step B (sibling commits = user/automation territory, same as Phase 2)"
  - "NO_DEPS_INSTALL map stays at 2 entries (COS-CIE, cos-signal-bridge); no new empirical additions required during Task 2"
metrics:
  duration_seconds: 284
  tasks: 4
  files_created: 3
  files_modified: 3
  commits: 3
  completed_date: "2026-04-19"
---

# Phase 3 Plan 02: API Pre-Render Pipeline Summary

Per-repo API pre-render pipeline wired end-to-end: `cos-docs/scripts/build-all-api.sh` loops 20 Python repos through isolated `uv venv .venv-docs` + `mkdocs build --strict`, extracts the Material `<article class="md-content__inner">` HTML, swaps it into each repo's `docs/api.md` as a `<div class="cos-docs-prerendered-api" markdown="0">` passthrough, and the aggregator `mkdocs build --strict` consumes it unchanged (20/20 OK; COS-Core field docstring "Lowercase exchange name" found 6× in final aggregator HTML, proving end-to-end render survived).

## What Shipped

### Task 0: BTC-Forge + COS-MSE per-repo strict-build fixes (Wave 0)

Reproduced both failures per 02-ROLLOUT-STATUS.md:

**BTC-Forge** — `src/api.py:75` (`scan_granularity_stats` docstring): the phrase `progress["exchanges"][exchange][granularity]` contained the bare word `exchange` which `mkdocs_autorefs` tried to resolve as a cross-reference, failing under `--strict`. Fix: wrapped identifiers in backticks and substituted `<exchange>` / `<granularity>` placeholders inside the code span (4-line diff). Post-fix `mkdocs build --strict` in BTC-Forge/.venv-docs exits 0.

**COS-MSE** — `src/mse/regimes/smoothing.py:4-6` (module docstring): a `Methods:` header followed by three `* bullet` lines parsed as a Google-style section, tripping griffe's `signature: description` parser on each bullet. Fix: collapsed the section into plain prose — "Supported smoothing methods: EWMA (exponentially weighted moving average), rolling mean, and rolling median." (4 lines removed, 2 added). Post-fix `mkdocs build --strict` in COS-MSE/.venv-docs exits 0.

Both diffs stay uncommitted on each sibling repo's `main` branch per plan Task 0 Step B directive ("sibling-repo commits happen separately by user or later automation, same pattern as Phase 2").

**A1 verification** — COS-Core fresh per-repo build produced `site/api/index.html` with exactly one match for the regex `<article[^>]*md-content__inner[^>]*>`; actual tag observed: `<article class="md-content__inner md-typeset">`. Regex in `build-all-api.sh` left unchanged.

### Task 1: `cos-docs/scripts/build-all-api.sh` (commit 5e174d1)

222-line bash script, chmod 755, `bash -n` clean. Mirrors `scaffold-all.sh` conventions:

- `PYTHON_REPOS` array with 20 entries + `-ne 20` audit guard (FATAL exit 2 on mismatch)
- `NO_DEPS_INSTALL` map: `COS-CIE` (needs xuer-sgl), `cos-signal-bridge` (needs cos-sdl) — cited inline with 02-02-SUMMARY.md evidence
- `REPO_STATUS` associative array + `printf "%-50s %s\n"` greppable summary
- Per-repo isolated `uv venv .venv-docs` + `requirements-docs.txt` install + `-e .` (or `--no-deps -e .`) + `mkdocs build --strict -d .api-staging`
- Inline `python3` extractor (single-quoted heredoc `<<'PY_EXTRACT'` — shell-injection safe) applies regex `<article[^>]*md-content__inner[^>]*>(.*?)</article>` with `re.DOTALL`, wraps the body in `# API\n\n<div class="cos-docs-prerendered-api" markdown="0">\n...</div>\n`, writes via `tmp → .replace()` atomic rename
- Three modes: default full (runs + restores), `--keep` (runs + leaves swapped for aggregator build), `--restore` (restores originals only)
- `append_gitignore_if_missing` idempotently adds `.venv-docs/`, `.api-staging/`, `site/`, `docs/api.md.pre-render-backup` to each repo's `.gitignore`
- `backup_api_md` + `restore_api_md` via `docs/api.md.pre-render-backup` sidecar file

### Task 2: E2E sweep (commit 2a6c285)

`./scripts/build-all-api.sh --keep` → **20/20 OK** in `.build-all-api-status.md`. Aggregator `.venv-aggr` + `mkdocs build --strict` exits 0 (build time 21.15s). Verification:

| Check | Expected | Result |
|-------|----------|--------|
| `grep -l '^:::' site/*/api/index.html` | empty | **empty ✓** (no literal `:::` leak) |
| `grep -l 'cos-docs-prerendered-api' site/{repo}/api/index.html` for all 20 | 20 hits | **20 ✓** |
| `grep -l 'markdown="0"' site/*/api/index.html` | 20 | **20 ✓** (div survived md_in_html passthrough) |
| `grep -c 'Lowercase exchange name' site/COS-Core/api/index.html` (Pitfall 5 field-docstring smoke) | ≥ 1 | **6 ✓** |
| `./scripts/build-all-api.sh --restore` → per-repo docs/api.md back to declarative | `:::` present | **6 hits** in COS-Core/docs/api.md, **6 hits** in COS-SGL/docs/api.md ✓ |

No repo required `NO_DEPS_INSTALL` additions during Task 2 — the 2 seeded entries (COS-CIE, cos-signal-bridge) remain the only repos needing `--no-deps`.

### Task 3: PROJECT.md API-02 Key Decision recorded (commit d519714)

Updated the "Defer API-docs strategy" row's Outcome from `— Pending` to a Phase-3-resolved citation. Added a new `API-docs Strategy` row with full decision trail (upstream #73, xuer-sgl / cos-sdl evidence, `<div markdown="0">` passthrough mechanism, Phase 4 CI drop-in contract). All Task 3 acceptance grep gates pass (see below).

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| BTC-Forge strict | `(cd BTC-Forge && .venv-docs/bin/mkdocs build --strict)` | exit 0 |
| COS-MSE strict | `(cd COS-MSE && .venv-docs/bin/mkdocs build --strict)` | exit 0 |
| A1 regex | `grep -cE '<article[^>]*md-content__inner[^>]*>' COS-Core/site/api/index.html` | 1 |
| Script syntax | `bash -n scripts/build-all-api.sh` | clean |
| build-all-api.sh --keep | 20/20 OK | ✓ |
| Aggregator strict | `cd cos-docs && mkdocs build --strict` | exit 0 (21.15s) |
| Passthrough proof | `grep -l 'markdown="0"' site/*/api/index.html \| wc -l` | 20 |
| No `:::` leak | `grep -l '^:::' site/*/api/index.html` | empty |
| End-to-end field docstring | `grep -c 'Lowercase exchange name' site/COS-Core/api/index.html` | 6 |
| Restore | `grep -c '^:::' COS-Core/docs/api.md` (post-restore) | 6 |
| PROJECT.md API-02 | `grep 'API-docs Strategy' .planning/PROJECT.md` | found |
| PROJECT.md no pending | `grep '— Pending' '^\|[^\|]*Defer API-docs' line` | absent |

## build-all-api.sh Contract

| Flag | Behavior |
|------|----------|
| (none / `full`) | Sweep all 20 repos, write `.build-all-api-status.md`, restore originals on exit |
| `--keep` | Sweep + leave per-repo `docs/api.md` swapped for aggregator build; does NOT restore |
| `--restore` | Restore originals only (reset after `--keep`); no build |

**Status file path:** `cos-docs/.build-all-api-status.md`
**Per-repo log dir:** `$(mktemp -d -t build-all-api.XXXXXX)` (e.g., `/tmp/build-all-api.hYcZk7/` — ephemeral, printed at end of run)
**Exit code:** always 0 in full/--keep modes (continue-on-failure per D-03); FATAL exit 2 only on audit-count guard mismatch

## PROJECT.md Key Decision Text (verbatim)

The new row added to PROJECT.md Key Decisions table:

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| API-docs Strategy: pre-rendered per-repo via isolated venv + HTML passthrough | Upstream mkdocs-monorepo-plugin issue #73: child `plugins:` are NOT executed by the parent aggregator build. Mega-venv alternative fails on workspace-dep packages not on PyPI (02-02-SUMMARY.md evidence: COS-CIE needs xuer-sgl, cos-signal-bridge needs cos-sdl). Pre-rendering each Python repo in its own `.venv-docs` (`uv venv` + `pip install -r requirements-docs.txt` + `pip install -e .` with `--no-deps` fallback for COS-CIE/cos-signal-bridge) produces Material HTML which build-all-api.sh extracts and passes through aggregator via `<div markdown="0">` per Material `md_in_html`. Phase 4 will wrap build-all-api.sh's per-repo loop body in a GitHub Actions matrix, not replace it. | Phase 3 shipped (03-02). API-02 + API-03 satisfied; 20/20 Python repos pre-render OK, aggregator `mkdocs build --strict` exits 0. |

The prior "Defer API-docs strategy..." row's Outcome was flipped from `— Pending` to the Phase 3 resolution citation referencing 02-02-SUMMARY.md.

## Deviations from Plan

None — plan executed exactly as written. No deviations required (no Rule 1-4 triggers during execution).

## Known Stubs

None. Every Python repo in scope emits a fully rendered `<div class="cos-docs-prerendered-api">` passthrough block; the literal `::: <module>` declarative form is preserved on disk (restored after --keep-driven aggregator build).

## Authentication Gates

None.

## Threat Flags

None new. Threat register dispositions (T-03-02-01..08) all honored:

- T-03-02-01 (supply-chain): per-repo `requirements-docs.txt` pins untouched by this plan
- T-03-02-02 (shell injection): `$repo` values originate from static 20-entry array; single-quoted heredoc `<<'PY_EXTRACT'` prevents Python-block interpolation
- T-03-02-03 (HTML/Python injection): extractor reads trusted Material template output; atomic tmp→rename; `markdown="0"` guarantees no re-parse
- T-03-02-04 (sibling docs/api.md tampering): backup/restore pattern verified green (Task 2 restore step)
- T-03-02-05 (DoS): build time ~1-2 min/repo × 20 = ~20-40 min observed; per-repo teardown of .venv-docs prevents disk bloat
- T-03-02-06 (info disclosure): status file contains only OK/FAIL strings + log paths
- T-03-02-07 (repudiation): per-repo logs in `$LOG_DIR` (printed at run-end) retain per-repo stdout/stderr

## Commits

| # | Hash | Scope | Message |
|---|------|-------|---------|
| 1 | 5e174d1 | cos-docs | feat(03-02): add build-all-api.sh per-repo API pre-render orchestrator |
| 2 | 2a6c285 | cos-docs | docs(03-02): record build-all-api status — 20/20 OK |
| 3 | d519714 | cos-docs | docs(03-02): record API-02 Key Decision — pre-rendered per-repo strategy |

Sibling-repo diffs (uncommitted, by plan design — see Task 0 Step B):

- `BTC-Forge/src/api.py` (4-line docstring rewrite, on `main`)
- `COS-MSE/src/mse/regimes/smoothing.py` (5-line docstring rewrite, on `main`)

## Metrics

| Metric | Value |
|--------|-------|
| Duration | 284 s |
| Tasks executed | 4/4 (Wave 0 Task 0 + Tasks 1-3) |
| Python repos pre-rendered | 20 / 20 OK |
| cos-docs commits | 3 |
| Sibling-repo uncommitted fixes | 2 (BTC-Forge, COS-MSE — per plan directive) |
| Aggregator strict build | exit 0 (21.15s, 20/20 populated API pages) |
| PROJECT.md rows touched | 2 (1 updated, 1 added) |

## Self-Check: PASSED

- FOUND: /home/btc/github/cos-docs/scripts/build-all-api.sh (executable)
- FOUND: /home/btc/github/cos-docs/.build-all-api-status.md
- FOUND: /home/btc/github/cos-docs/.planning/PROJECT.md (contains "API-docs Strategy")
- FOUND: /home/btc/github/cos-docs/.planning/phases/03-aggregator-api-strategy/03-02-SUMMARY.md
- FOUND commit 5e174d1 in cos-docs
- FOUND commit 2a6c285 in cos-docs
- FOUND commit d519714 in cos-docs
- VERIFIED: BTC-Forge strict build exit 0 after fix
- VERIFIED: COS-MSE strict build exit 0 after fix
- VERIFIED: aggregator strict build exit 0, 20/20 passthrough markers
- VERIFIED: restore round-trip (`:::` directives present post-restore)
