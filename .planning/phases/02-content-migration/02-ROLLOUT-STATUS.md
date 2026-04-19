# Phase 2 Rollout Status

**Run:** 2026-04-19T19:38:04Z (initial sweep) + 2026-04-19T20:00Z (PACKAGE_OVERRIDES re-runs) + 2026-04-19T21:30Z (dirty/branch triage sweep)
**Wrapper:** /home/btc/github/cos-docs/scripts/scaffold-all.sh
**Per-repo log dir:** /tmp/scaffold-all.wwjz0t

## Summary

| Status          | Count |
|-----------------|-------|
| OK              | 26    |
| SKIP (excluded) | 2     |
| FAIL            | 2     |
| TOTAL           | 30    |

**Accounting:**
- OK = scaffold committed on main/master in target repo AND `mkdocs build --strict` passes
- SKIP = intentionally excluded (aggregator self-reference or lowercase duplicate)
- FAIL = scaffold + commit landed, but `mkdocs build --strict` fails due to pre-existing source-content issues (not a scaffold bug)

**Gate:** Plan target ≥25 OK met (26/30). The two FAIL repos have scaffold commits on main; their build failures are source-code hygiene (docstring-parse, broken cross-refs) and are categorised as out-of-scope for Phase 2 tooling.

## Per-Repo Detail

| Repo | Status | Reason | Remediation |
|------|--------|--------|-------------|
| bis-forge | OK | Triage sweep: stash-scaffold-pop + `--package bis` (PACKAGE_OVERRIDE backported) | commit `9398171` |
| bls-forge | OK | Triage sweep: stash-scaffold-pop + `--package bls` (PACKAGE_OVERRIDE backported) | commit `d29c062` |
| BTC-Forge | FAIL | Scaffold + `--package src` committed (`b615dc2`), but `mkdocs build --strict` fails: `mkdocs_autorefs` cannot resolve `exchange` cross-ref from `src/api.py:75` docstring. Root cause: pre-existing source-code docstring hygiene (same category as COS-MSE). | Fix the `scan_granularity_stats` docstring in `src/api.py` (remove or qualify the `exchange` reference); re-run `.venv-docs/bin/mkdocs build --strict` to verify. Out of Phase 2 scope. |
| capability-gated-agent-architecture | SKIP | EXCLUDED (D-12: lowercase duplicate of COS-Capability-Gated-Agent-Architecture) | None — intentional |
| coinbase_websocket_BTC_pricefeed | OK | Triage sweep: kubernetes→main checkout-scaffold-restore | commit `e4b2701` |
| COS-Bitcoin-Protocol-Intelligence-Platform | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package backend`) | commit `d6c8a03` |
| COS-BTC-Network-Crawler | OK | Wrapper initial sweep | commit `4557877` |
| COS-BTC-Node | OK | Triage sweep: stash-scaffold-pop | commit `e508672` |
| COS-BTC-SQL-Warehouse | OK | Triage sweep: stash-scaffold-pop (INFO-level warnings about pre-existing `spec_v1.2.md` not in nav and one internal anchor miss — non-blocking) | commit `92e3cc8` |
| COS-BTE | OK | Triage sweep: stash-scaffold-pop | commit `bf550e6` |
| COS-Capability-Gated-Agent-Architecture | OK | Triage sweep: spec-decomposition-extraction→main checkout-scaffold-restore (DIAGRAM_EXEMPT) | commit `763382e` |
| COS-CIE | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package cos_cie`, `pip install --no-deps`) | commit `a3d8591` |
| cos-data-access | OK | Wrapper initial sweep | commit `c1b7072` |
| cos-docs | SKIP | EXCLUDED (aggregator self-reference) | None — intentional |
| COS-Hardware | OK | Triage sweep: stash-scaffold-pop (DIAGRAM_EXEMPT) | commit `75b42e1` |
| COS-Infra | OK | Scaffold + hand-edit of pre-existing broken `../CHANGELOG.md` link in `docs/DEPLOYMENT_GUIDE.md` (replaced with plain text reference); scaffold.sh template bug fixed upstream (now omits api.md link on docs-only repos) | commit `58be747` |
| COS-LangGraph | OK | Wrapper initial sweep (seeded PACKAGE_OVERRIDE `langgraph_agent`) | commit `2835ccf` |
| COS-MSE | FAIL | Scaffold committed, but `mkdocs build --strict` fails: griffe docstring-parse warnings from bullet-list docstrings in `src/mse/regimes/smoothing.py:4-6`. Source-code hygiene, out of Phase 2 scope. | Reformat bullet-list docstrings to Griffe-parseable format; re-run `.venv-docs/bin/mkdocs build --strict`. |
| COS-Network | OK | Triage sweep: scaffold.sh template fix (api.md link now omitted on docs-only repos) | commit `dbfb434` |
| COS-SGL | OK | Triage sweep: stash-scaffold-pop | commit `2178a2b` |
| cos-signal-bridge | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package signal_bridge`, `pip install --no-deps`) | commit `3b66154` |
| cos-signal-explorer | OK | Triage sweep: stash-scaffold-pop | commit `73c8142` |
| cos-webpage | OK | Triage sweep: stash-scaffold-pop | commit `7396ca9` |
| EDGAR-Forge | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package edgar`) | commit `8a28715` |
| FRED-Forge | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package src`) | commit `1a8d963` |
| imf-forge | OK | Triage sweep: stash-scaffold-pop + `--package imf` (PACKAGE_OVERRIDE backported) | commit `301b0c6` |
| ingest | OK | Initial sweep + PACKAGE_OVERRIDES backport (`--package ingest_shared`) | commit `7e6e2fc` |
| OrbWeaver | OK | Triage sweep: kubernetes→main checkout-scaffold-restore | commit `c1b0564` |
| quant-dashboard | OK | Triage sweep: stash-scaffold-pop + kubernetes→master checkout-scaffold-restore (substantial staged-rename WIP preserved intact) | commit `5b5d49b` |
| stooq-forge | OK | Triage sweep: stash-scaffold-pop | commit `eb10919` |

## Failure Triage Notes

### Triage sweep (2026-04-19 continuation) — +17 resolved

Following the initial sweep + PACKAGE_OVERRIDES re-run that yielded 9 OK, a triage pass was run to process the 17 repos SKIP'd at preflight (13 dirty + 4 branch):

- **4 branch repos** — ran in `stash (if dirty) → checkout main/master → scaffold+commit → checkout original-branch → stash pop` pattern. All 4 preserved their feature-branch WIP. quant-dashboard had substantial staged renames on its kubernetes branch; stash pop restored them cleanly (renames shown as D+A pairs post-pop, semantically identical).
- **12 dirty repos** — ran in `stash (with -u) → scaffold+commit → stash pop` pattern. 4 of the 12 (all `*-forge` repos) initially landed a broken api.md because their module names didn't match their pyproject `[project].name` — all 4 (bis-forge → `bis`, bls-forge → `bls`, imf-forge → `imf`, BTC-Forge → `src`) were investigated, backported into `PACKAGE_OVERRIDES`, and their commits amended. 3 of those 4 (bis, bls, imf) now pass strict; BTC-Forge still fails on a pre-existing docstring autoref issue and is classified FAIL.

### FAIL → OK resolution paths (during this plan)

10 repos hit `mkdocs build --strict` failures at some point during the plan, all resolved (or reclassified):

- **Module-name mismatch (Pitfall 4, `PACKAGE_OVERRIDES`)** — 10 repos discovered:
  COS-Bitcoin-Protocol-Intelligence-Platform, COS-CIE, COS-MSE*, cos-signal-bridge, EDGAR-Forge, FRED-Forge, ingest (from initial sweep); bis-forge, bls-forge, imf-forge, BTC-Forge* (from triage sweep). * = landed override but still FAIL for a different source-content reason.
- **Workspace-dep install (`pip install -e .` fails on local deps not on PyPI)** — 2 repos: COS-CIE (needs `xuer-sgl`), cos-signal-bridge (needs `cos-sdl`). Resolved manually via `--no-deps`. Tool improvement deferred: add `NO_DEPS_INSTALL` list to `scaffold-all.sh`.
- **Scaffold template bug (index.md references api.md on docs-only repos)** — 2 repos: COS-Network, COS-Infra. Fixed in `scaffold.sh:emit_index_md` (cos-docs commit `371b545`) — `repo_type` arg now gates the API quick-link line.
- **Pre-existing source content** — 2 repos remain FAIL: COS-MSE (griffe docstring-parse), BTC-Forge (mkdocs_autorefs unresolved cross-ref). Both have scaffold commits; their build failures are documentation-source hygiene issues orthogonal to the scaffold pipeline.

### FAIL (pre-existing source) — 2 repos

1. **BTC-Forge** — commit `b615dc2` — `mkdocs_autorefs: api.md: from /home/btc/github/BTC-Forge/src/api.py:75: (src.api.scan_granularity_stats) Could not find cross-reference target 'exchange'`. Fix = update `scan_granularity_stats` docstring to remove the bare `exchange` reference or qualify it.
2. **COS-MSE** — commit per initial sweep — griffe docstring-parse warnings from `src/mse/regimes/smoothing.py:4-6`. Fix = reformat bullet-list docstrings to Griffe-parseable format.

## PACKAGE_OVERRIDES Additions (Backported)

All 11 overrides are now codified in `/home/btc/github/cos-docs/scripts/scaffold-all.sh`:

| Repo | Module | Root cause | Sweep |
|------|--------|------------|-------|
| COS-LangGraph | `langgraph_agent` | Seeded in plan 02-01 | (pre-existing) |
| COS-Bitcoin-Protocol-Intelligence-Platform | `backend` | pyproject `name=bpip`, `packages=["backend"]` | Initial |
| COS-CIE | `cos_cie` | pyproject `name=cos-cie` (hyphen) vs module `cos_cie` (underscore) | Initial |
| COS-MSE | `mse` | pyproject `name=market-sentiment-engine`, `packages=["src/mse"]` | Initial |
| cos-signal-bridge | `signal_bridge` | pyproject `name=cos-signal-bridge`, `packages=["src/signal_bridge"]` | Initial |
| EDGAR-Forge | `edgar` | pyproject `name=edgar-forge`, `packages=["edgar"]` | Initial |
| FRED-Forge | `src` | pyproject `name=fred-forge`, `packages=["src", ...]` — literal "src" is the module (loose-files layout) | Initial |
| ingest | `ingest_shared` | pyproject `name=ingest`, `packages=["src/connectors","src/ingest_shared"]` — picking `ingest_shared` | Initial |
| bis-forge | `bis` | pyproject `name=bis-forge`, `packages=["src/bis"]` | Triage |
| bls-forge | `bls` | pyproject `name=bls-forge`, `packages=["src/bls"]` | Triage |
| imf-forge | `imf` | pyproject `name=imf-forge`, `packages=["src/imf"]` | Triage |
| BTC-Forge | `src` | pyproject `name=btc-ohlcv-forge`, `packages=["src", "src.core", "src.exchanges"]` — literal "src" is the module | Triage |

## Final Counts

- **OK: 26**
- **SKIP (intentional exclusions): 2** (cos-docs, capability-gated-agent-architecture)
- **FAIL (pre-existing source content): 2** (BTC-Forge, COS-MSE)

**Plan target ≥25 OK: met (26).** CONT-01 satisfied (auditable per-repo record of which repos are scaffolded). Of the remaining 2 FAILs, both have scaffold commits on their main branch; the failures are documentation-source cleanups that are properly the responsibility of the source repos' content owners, not the cos-docs aggregation pipeline.

## References

- Plan: `/home/btc/github/cos-docs/.planning/phases/02-content-migration/02-02-PLAN.md`
- Wrapper: `/home/btc/github/cos-docs/scripts/scaffold-all.sh` (PACKAGE_OVERRIDES updated — 11 entries)
- Scaffold fix: cos-docs commit `371b545` (`scaffold.sh:emit_index_md` repo_type arg)
- Per-repo initial sweep logs: `/tmp/scaffold-all.wwjz0t/`
- Triage helper: `/tmp/rollout_single.sh` (ad-hoc; not a shipped artifact)
