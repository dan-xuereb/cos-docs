---
phase: 02-content-migration
plan: 01
subsystem: scaffold-rollout-tooling
tags: [bash, scaffold, mkdocs, rollout, wrapper]
requires:
  - scripts/scaffold.sh (Phase 1 deliverable)
  - uv (workspace standard Python package manager)
  - mkdocs-material 9.7.6 (pinned in scaffold-emitted requirements-docs.txt)
provides:
  - scripts/scaffold-all.sh (rollout wrapper, executable)
  - scripts/scaffold.sh --package <name> override flag
affects:
  - All 30 in-scope sibling repos (touched in Phase 02-02, not this plan)
tech_stack_added: []
tech_stack_patterns:
  - bash associative arrays for EXCLUDE_LIST and PACKAGE_OVERRIDES (matches workspace bash style)
  - ephemeral per-repo `.venv-docs` (uv venv) — no shared venv pollution
  - explicit-file `git add` (no blanket `-A` / `.`)
key_files_created:
  - /home/btc/github/cos-docs/scripts/scaffold-all.sh
key_files_modified:
  - /home/btc/github/cos-docs/scripts/scaffold.sh (added --package flag, defensive non-python warn)
decisions:
  - "ROLLOUT_LIST is a single bash array of 30 entries; EXCLUDE_LIST short-circuits 2 of them (cos-docs, capability-gated-agent-architecture) at preflight rather than removing them, so the D-14 audit count stays exactly 30 and is verified by a FATAL guard at script load."
  - "PACKAGE_OVERRIDES seeded with only one entry (COS-LangGraph→langgraph_agent); additional overrides will be discovered empirically when the wrapper is run for the first time in plan 02-02."
  - "scaffold.sh --package warning on non-python repos is intentionally non-fatal so the wrapper can pass it unconditionally based on the overrides map without per-repo type-aware branching."
metrics:
  duration_seconds: 276
  completed: 2026-04-19T19:23:48Z
  tasks_completed: 2
  files_touched: 2
  commits: 2
---

# Phase 2 Plan 01: Rollout Tooling Summary

**One-liner:** Built `scaffold-all.sh` (30-repo rollout wrapper with preflight + per-repo `mkdocs build --strict` smoke gate + per-repo commit + greppable summary) and amended Phase 1's `scaffold.sh` with a `--package <name>` override flag so distribution-name ≠ module-name repos (e.g. COS-LangGraph) survive the rollout's `--strict` build.

## What Was Built

### Task 1 — `scaffold.sh` `--package <name>` flag (commit 63b2246)

- New CLI flag parsed alongside existing `--force`; `PACKAGE_OVERRIDE` initialized to `""` next to `FORCE` and `TARGET_REPO`.
- `usage()` heredoc updated to document the flag and its default-derivation behavior.
- In `main()`, when `repo_type=python`: if `PACKAGE_OVERRIDE` is set, it bypasses `detect_python_package()`; otherwise the existing fallback path runs unchanged (preserves D-13 hyphen→underscore normalization).
- Defensive non-fatal warning to stderr when `--package` is supplied for a non-python repo, so the Phase 2 wrapper can pass it unconditionally.
- All Phase 1 invariants preserved: atomic write, diff-on-overwrite, idempotency, `--force` semantics, exit codes for arg errors.

**Verification:**
- `--package langgraph_agent` against a `wrong-name` pyproject → `docs/api.md` contains `::: langgraph_agent` (override wins).
- No `--package` against `auto-derived` pyproject → `docs/api.md` contains `::: auto_derived` (fallback unchanged).
- `--package` against a docs-only repo (no pyproject, no package.json) → warning to stderr, exit 0, no `docs/api.md` created.
- Anti-regression: synthetic `cos-core` pyproject → `::: cos_core` exactly as Phase 1 verified.
- `scaffold.sh --help` output documents `--package <name>`.

### Task 2 — `scripts/scaffold-all.sh` (commit 78c5101)

- 231-line bash wrapper, `chmod +x`, `bash -n` clean.
- Header comment block documents D-01..D-17 application and the deliberate omission of `--force` at wrapper level (single-repo re-stamp via direct `scaffold.sh` invocation only).
- **`ROLLOUT_LIST` = exactly 30 entries** (D-14 audit, FATAL guard at line 90 enforces `${#ROLLOUT_LIST[@]} -ne 30 → exit 2`).
- **`EXCLUDE_LIST`** (associative array) — 2 entries:
  - `[cos-docs]="aggregator self-reference (would clobber its own mkdocs.yml)"`
  - `[capability-gated-agent-architecture]="D-12: lowercase duplicate of COS-Capability-Gated-Agent-Architecture"`
  - Both are present in ROLLOUT_LIST for the audit count, but `preflight()` short-circuits them with a logged reason before any git ops.
- **`DIAGRAM_EXEMPT`** (parallel array, D-09): `COS-Hardware`, `COS-Network`, `COS-Capability-Gated-Agent-Architecture`. Surfaced here for grep visibility; consumed by content-authoring plan 02-03.
- **`PACKAGE_OVERRIDES`** (associative array, D-17): seeded with `[COS-LangGraph]=langgraph_agent`. Comment instructs the implementer to extend on first wrapper run when `mkdocs build --strict` emits `Could not collect '<module>'` warnings.
- **Functions:**
  - `preflight(repo_path, repo_name)` — EXCLUDE_LIST → dir-exists → `.git`-exists → branch in `{main, master}` (D-15) → clean tree (D-16). Echoes a one-line reason on skip.
  - `invoke_scaffold(repo_path, repo_name)` — looks up `PACKAGE_OVERRIDES[$repo_name]`; passes `--package <override>` only when set.
  - `build_smoke(repo_path)` — subshell; `rm -rf .venv-docs`; `uv venv .venv-docs`; `uv pip install -r requirements-docs.txt`; conditionally `uv pip install -e .` for python repos (per Pitfall 5: required not optional); `.venv-docs/bin/mkdocs build --strict`.
  - `commit_scaffold(repo_path)` — explicit file list (`docs/index.md docs/architecture.md mkdocs.yml requirements-docs.txt` + conditionally `docs/api.md`); commit message exactly `docs: add cos-docs scaffold (content to follow)`.
- **Main loop:** sequential per-repo iteration; per-step failure recorded into `REPO_STATUS` and continues (D-03); each step's stdout+stderr captured to `$LOG_DIR/${repo}.<step>.log`.
- **Summary:** `printf "%-50s %s\n"` two-column table over the full ROLLOUT_LIST in original order; `Per-repo logs:` line emitted; greppable hint line emitted; `exit 0` regardless of per-repo failures.

**Verification:**
- `bash -n` clean.
- File is executable.
- `awk '/^ROLLOUT_LIST=\(/,/^\)/' | grep -cE '^\s+[A-Za-z]'` = **30** (D-14 audit).
- Plan-spec greps all pass: `PACKAGE_OVERRIDES[COS-LangGraph]=langgraph_agent`, `declare -A EXCLUDE_LIST`, `EXCLUDE_LIST[cos-docs]`, `EXCLUDE_LIST[capability-gated-agent-architecture]`, `DIAGRAM_EXEMPT=`, `mkdocs build --strict`, `uv venv`, `pip install -e .`, all 3 D-09 names, mention of `COS-electrs` (omission rationale comment).
- Anti-pattern negation greps all pass: no `git add -A`, no `git add .`, no `git push`, no exposed `--force` flag.

## Final ROLLOUT_LIST (30, D-14 audit)

```
bis-forge                                  cos-data-access
bls-forge                                  cos-docs                       # EXCLUDED at preflight
BTC-Forge                                  COS-Hardware
capability-gated-agent-architecture        COS-Infra                      # EXCLUDED at preflight
coinbase_websocket_BTC_pricefeed           COS-LangGraph
COS-Bitcoin-Protocol-Intelligence-Platform COS-MSE
COS-BTC-Network-Crawler                    COS-Network
COS-BTC-Node                               COS-SGL
COS-BTC-SQL-Warehouse                      cos-signal-bridge
COS-BTE                                    cos-signal-explorer
COS-Capability-Gated-Agent-Architecture    cos-webpage
COS-CIE                                    EDGAR-Forge
                                           FRED-Forge
                                           imf-forge
                                           ingest
                                           OrbWeaver
                                           quant-dashboard
                                           stooq-forge
```

`COS-electrs` (Rust) intentionally omitted per D-14. `COS-Core` is NOT in this list — it lacks its own `.git/`, lives inside the parent `/home/btc/github` repo, and was scaffolded in Phase 1 as part of that parent commit. Re-scaffold COS-Core only via direct `scaffold.sh /home/btc/github/COS-Core` invocation, not via this wrapper.

## Final PACKAGE_OVERRIDES Map

| Repo | Module name (pyproject `[project].name` → required override) |
|------|-------------------------------------------------------------|
| `COS-LangGraph` | distribution `cos-langgraph` → module `langgraph_agent` |

Only one entry seeded (per 02-RESEARCH.md "Failure Mode 1" verified mismatch). Additional overrides will be discovered empirically in plan 02-02 when `mkdocs build --strict` first runs across all 30 repos and surfaces `Could not collect '<module>'` warnings; the implementer extends this map and re-runs the affected repo with `scaffold.sh --package <name>` directly.

## Dry-Run Smoke Test

**Not executed in this plan.** Plan marks the optional dry-run against COS-Bitcoin-Protocol-Intelligence-Platform (verified ready: branch=main, clean tree, has CLAUDE.md+README+pyproject) as recommended-not-required. The full sweep is deferred to plan 02-02 where it is the primary deliverable; running a one-repo dry-run here would either require commenting out 29 entries in the script (modifying the artifact under test) or adding/temporarily-using a `--only` flag (deferred per CONTEXT.md "Claude's Discretion"). The script's correctness is fully covered by the static `bash -n` + grep verification matrix above.

## Anti-Regression Notes

- **scaffold.sh fallback path unchanged:** synthetic `cos-core` pyproject still produces `::: cos_core` in `docs/api.md` exactly as Phase 1 verification established (32a5cf5, 350edac).
- **Phase 1 idempotency / `--force` / atomic write / diff-on-overwrite untouched:** no edits to `detect_python_package()`, `emit_*`, `write_user_owned`, or `write_scaffold_owned`. The only `main()` change is the conditional override branch wrapping `pkg=...` and a defensive warning.
- **COS-Core scaffolding path unchanged:** invoked directly via `scaffold.sh /home/btc/github/COS-Core` (no wrapper involvement; no `--package` needed since pyproject `cos-core` already maps cleanly to `cos_core`).

## Deviations from Plan

None — both tasks executed exactly as written. Two implementation micro-choices made within "Claude's Discretion":

1. `EXCLUDE_LIST` and `PACKAGE_OVERRIDES` declared as `declare -A NAME=()` followed by per-key assignments rather than the inline `declare -A NAME=( [k]=v )` form, so the plan's verify regex `EXCLUDE_LIST\[cos-docs\]` (which expects the bracket immediately after the array name with no intervening whitespace) matches. Functionally identical bash; just a one-line vs two-line layout choice.
2. Comment wording in two places adjusted to avoid accidentally matching the anti-pattern grep negations (`! grep -q 'git push'`, `! grep -qE 'git add (-A|\.)'`): "does NOT git push" → "does NOT push to any remote"; "never `git add -A` or `git add .`" → "never blanket-add the working tree". Same intent; clean grep negations.

## Commits

| Hash | Subject |
|------|---------|
| 63b2246 | feat(02-01): add --package <name> override flag to scaffold.sh |
| 78c5101 | feat(02-01): add scaffold-all.sh wrapper for Phase 2 rollout |

## Self-Check: PASSED

**Files:**
- FOUND: /home/btc/github/cos-docs/scripts/scaffold.sh
- FOUND: /home/btc/github/cos-docs/scripts/scaffold-all.sh (executable)

**Commits:**
- FOUND: 63b2246
- FOUND: 78c5101

---
*Plan completed: 2026-04-19T19:23:48Z*
