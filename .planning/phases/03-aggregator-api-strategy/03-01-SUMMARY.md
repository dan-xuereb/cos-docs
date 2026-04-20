---
phase: 03-aggregator-api-strategy
plan: 01
subsystem: aggregator
tags: [mkdocs, aggregator, monorepo-plugin, strict-build]
requires: [per-repo-mkdocs-yml-scaffold]
provides: [aggregator-mkdocs-yml, aggregator-requirements-docs, aggregator-strict-build-green]
affects: [cos-docs, 29-sibling-repos-nav]
tech_added: [mkdocs==1.6.1, mkdocs-material==9.7.6, mkdocs-monorepo-plugin==1.1.2, pymdown-extensions]
patterns: [atomic-write, preflight-existence-check, pre-render-isolation-per-issue-73]
key_files_created:
  - cos-docs/mkdocs.yml
  - cos-docs/requirements-docs.txt
  - cos-docs/docs/index.md
key_files_modified: []
decisions:
  - "Aggregator venv excludes mkdocstrings + griffe-pydantic (deferred to per-repo .venv-docs in 03-02 per upstream mkdocs-monorepo-plugin #73)"
  - "29-repo nav under 8 locked domain groups (quant-dashboard-k8s-deployment dropped after confirming absent on disk)"
  - "Placeholder docs/index.md ships in 03-01; full repo-index table deferred to 03-03"
metrics:
  duration_seconds: 178
  tasks: 3
  files_created: 3
  commits: 3
  completed_date: "2026-04-20"
---

# Phase 3 Plan 01: Aggregator mkdocs.yml + Pin Matrix Summary

MkDocs aggregator wired: `cos-docs/mkdocs.yml` composes 29 sibling repos via `!include` across 8 domain groups, `mkdocs build --strict` exits 0, and the pin matrix deliberately omits API renderers per upstream issue #73.

## Pre-work: Sibling-Repo Scaffold Cherry-Picks

Before Task 1, cherry-picked the Phase 2 scaffold commit onto the 4 sibling branches whose `main` scaffolds were not present on their currently-checked-out branches:

| Repo | Branch | Source Hash | New Hash | Notes |
|------|--------|-------------|----------|-------|
| coinbase_websocket_BTC_pricefeed | kubernetes | e4b2701 | 5da13fe | clean tree |
| OrbWeaver | kubernetes | c1b0564 | a62d33f | clean tree (untracked only) |
| COS-Capability-Gated-Agent-Architecture | spec-decomposition-extraction | 763382e | 06defae | clean tree (untracked only) |
| quant-dashboard | kubernetes | 5b5d49b | f4a0b51 | 40 dirty files — stashed before CP, restored after (user-approved per WIP notice); zero file overlap with scaffold |

All 4 cherry-picks succeeded with exit 0. No conflicts.

## What Shipped

### Task 1: Preflight (read-only)
29-repo `!include` target existence check passed: `OK: 29/29 !include targets present.` The two Phase 2 FAIL repos (BTC-Forge, COS-MSE) both have `mkdocs.yml` on disk (their API-docstring failures live inside `docs/api.md`, not in the mkdocs config — that's 03-02 Wave 0 territory).

### Task 2: `cos-docs/requirements-docs.txt` (commit d8b9027)
Four pinned lines only:
```
mkdocs==1.6.1
mkdocs-material==9.7.6
mkdocs-monorepo-plugin==1.1.2
pymdown-extensions>=10.9
```
`uv pip install` in fresh `.venv-aggr-test` resolved cleanly (exit 0). File header comment documents the deliberate omission of API-rendering deps per D-01.

### Task 3: `cos-docs/mkdocs.yml` + `cos-docs/docs/index.md` (commit eb1611d)
- 29 `!include ../<repo>/mkdocs.yml` entries (verified by `grep -c '!include \.\./'`)
- 8 domain headers: Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure (verified by grep)
- `site_url: http://10.70.0.102:30081/`, `md_in_html`, Mermaid custom_fence
- Plugins: `search` + `monorepo` (no API renderer)
- Placeholder `docs/index.md` with H1 "Xuer Capital Workspace Docs"

## Strict-Build Gate — Output Tail

```
INFO    -  Cleaning site directory
INFO    -  Building documentation to directory: /home/btc/github/cos-docs/site
INFO    -  The following pages exist in the docs directory, but are not included in the "nav" configuration:
  - COS-BTC-SQL-Warehouse/spec_v1.2.md
  - COS-Infra/{13 loose .md files}
  - quant-dashboard/{2 loose .md files}
INFO    -  Doc file 'COS-BTC-SQL-Warehouse/spec_v1.2.md' contains a link '#5-staging-layer--parquet-archive', but there is no such anchor on this page.
INFO    -  Documentation built in 1.58 seconds
=== BUILD EXIT: 0 ===
=== repo subdir count: 29 ===
```

Exit 0 against `--strict`. INFO lines are informational (not `WARNING`); they list loose per-repo .md files not listed in their respective per-repo nav blocks — **out of scope for 03-01** (per-repo nav hygiene belongs to 03-03). One internal-anchor INFO in `COS-BTC-SQL-Warehouse/spec_v1.2.md` is a pre-existing content issue; not strict-breaking.

## Acceptance Criteria — All Passed

- `grep -c '!include \.\./' mkdocs.yml` = **29** ✓
- 8 domain headers verified ✓
- `site_url: http://10.70.0.102:30081/` present ✓
- `md_in_html` extension present ✓
- `monorepo` + `search` plugins both present ✓
- `mkdocstrings` absent from both `mkdocs.yml` and `requirements-docs.txt` ✓
- `quant-dashboard-k8s-deployment` absent (D-13 confirmed absent on disk) ✓
- `COS-electrs` absent (D-14 exclusion) ✓
- Lowercase `capability-gated-agent-architecture` absent (D-12 exclusion) ✓
- `docs/index.md` H1 present ✓
- `mkdocs build --strict` exits 0 ✓
- `site/` contains 29 repo subdirs ✓

## Teardown Verification

No `.venv-aggr/` or `site/` committed. `git status --short` after Task 3 shows only the tracked new files + pre-existing `.planning/phases/03-aggregator-api-strategy/03-PATTERNS.md` (untracked, unrelated to this plan).

## Deviations from Plan

**1. [Rule 3 - Blocking] quant-dashboard cherry-pick required stash/pop around 40 dirty files.**
- **Found during:** pre-Task-1 cherry-pick sequence
- **Issue:** `git cherry-pick 5b5d49b` failed with "your local changes would be overwritten" on the `kubernetes` branch (user had 40 modified files).
- **Fix:** Verified zero file overlap between WIP and scaffold (scaffold only adds new paths: `docs/`, `mkdocs.yml`, `requirements-docs.txt`; WIP was all `src/widgets/**` + related). Stashed WIP with `git stash push -u`, cherry-picked, then `git stash pop` — no conflicts on pop. WIP restored exactly (40 dirty files present after). User had pre-authorized this repo despite WIP.
- **Files modified:** /home/btc/github/quant-dashboard (cherry-pick only — scaffold files)
- **Commit:** f4a0b51 in quant-dashboard (not cos-docs)

**2. [Rule 2 - Correctness] mkdocs.yml / requirements-docs.txt comment wording.**
- **Found during:** Task 2 + Task 3 acceptance-criteria grep assertions
- **Issue:** First-draft comments contained the substrings `mkdocstrings` and `griffe-pydantic` as prose inside explanatory header blocks — this defeated the `! grep -q mkdocstrings` and `! grep -q griffe-pydantic` acceptance gates.
- **Fix:** Rewrote both files' comments to describe the intent ("API-rendering deps", "API rendering runs only in per-repo .venv-docs") without naming the packages literally. Intent preserved; grep gates now pass.
- **Files modified:** cos-docs/requirements-docs.txt, cos-docs/mkdocs.yml (pre-commit; folded into Task 2 / Task 3 commits)

## Known Stubs

- `cos-docs/docs/index.md` — intentional placeholder per plan spec; 03-03 replaces with full repo-index table + quick-start + domain overviews (D-11).

## Authentication Gates

None.

## Threat Flags

None new. Threat register dispositions (T-03-01-01..05) all honored:
- T-03-01-01 mitigated: exact `==` pins on 3 of 4 deps; floor only on pymdown-extensions per plan
- T-03-01-02 mitigated: Task 1 preflight enforced existence of all 29 `!include` targets
- T-03-01-04 mitigated: `.venv-aggr/` + `site/` torn down post-build, not committed

## Commits

| # | Hash | Scope | Message |
|---|------|-------|---------|
| 1 | d8b9027 | cos-docs | feat(03-01): add aggregator requirements-docs.txt with 4 pins |
| 2 | eb1611d | cos-docs | feat(03-01): add aggregator mkdocs.yml + placeholder index.md |

Plus 4 sibling-repo scaffold cherry-pick commits (one per repo, listed in pre-work table above).

## Metrics

| Metric | Value |
|--------|-------|
| Duration | 178 s |
| Tasks executed | 3/3 |
| Files created | 3 |
| Cos-docs commits | 2 |
| Sibling-repo CP commits | 4 |
| Strict-build result | exit 0, 29 subdirs |

## Self-Check: PASSED

- FOUND: /home/btc/github/cos-docs/mkdocs.yml
- FOUND: /home/btc/github/cos-docs/requirements-docs.txt
- FOUND: /home/btc/github/cos-docs/docs/index.md
- FOUND commit d8b9027 in cos-docs
- FOUND commit eb1611d in cos-docs
- FOUND 5da13fe in coinbase_websocket_BTC_pricefeed (kubernetes)
- FOUND a62d33f in OrbWeaver (kubernetes)
- FOUND 06defae in COS-Capability-Gated-Agent-Architecture (spec-decomposition-extraction)
- FOUND f4a0b51 in quant-dashboard (kubernetes)
