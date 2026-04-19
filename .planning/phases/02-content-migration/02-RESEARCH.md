# Phase 2: Content Migration - Research

**Researched:** 2026-04-19
**Domain:** Bash batch-rollout wrapper + per-repo MkDocs build smoke + hand-authoring workflow ergonomics across ~25 sibling repos
**Confidence:** HIGH (filesystem-verified facts), MEDIUM (mkdocstrings import behavior on heavy repos)

## Summary

Phase 2 is operationally simple but logistically dense: write a thin wrapper (`scaffold-all.sh`) that loops Phase 1's `scaffold.sh` over a hardcoded sibling-repo list, runs `mkdocs build --strict` per repo as a smoke gate, and stops there. Humans hand-author content per repo (D-05).

The non-obvious risk is **not** the wrapper bash — it's the **gap between CONTEXT.md's assumed repo list and what's actually on disk**. The CLAUDE.md project map (D-11) is stale relative to `/home/btc/github/`: 6 listed repos are missing or renamed (`fred-forge` → `FRED-Forge`, `bitcoin_node` → `COS-BTC-Node`, `edgar-forge` → `EDGAR-Forge`, `bis-forge`/`bls-forge`/`imf-forge` are correctly lowercased, `BTC-Forge` matches), and 8 disk repos are absent from the map (`COS-MSE`, `cos-data-access`, `cos-signal-explorer`, `cos-webpage`, `COS-electrs` (Rust!), `COS-Infra`, `COS-BTC-Node`, `stooq-forge`). The actual git-repo count in `/home/btc/github/` is **31**, not 25.

A second risk: D-02 says "commit directly on each repo's `main` branch" — but **8 of 31 repos are not on `main`** right now (some on `master`, `kubernetes`, or feature branches), and **14 of 31 have uncommitted working-tree changes**. The wrapper must explicitly handle this rather than blindly `git add && git commit`.

**Primary recommendation:** Before any wrapper coding, the planner MUST resolve the rollout-list authority (rebuild from `ls /home/btc/github/`, not from CLAUDE.md project map verbatim) and add explicit pre-flight checks for branch-name + clean-tree state. The bash itself is ~80 lines; the value of Phase 2 lives in the rollout-list quality and the per-repo failure-mode handling, not the script complexity.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Rollout Mechanics**
- **D-01:** Add a thin wrapper `cos-docs/scripts/scaffold-all.sh` that iterates a hardcoded list of sibling repo paths and shells out to Phase 1's `scaffold.sh` per repo. Phase 1 D-04 stands — `scaffold.sh` remains single-repo; the batch list lives in the wrapper.
- **D-02:** Per-repo commit strategy: **one commit per sibling repo**, directly on that repo's `main` branch. Solo maintainer, internal docs, no PR overhead. Commit message convention: `docs: add cos-docs scaffold + initial content`. Each sibling repo's git history records the scaffold separately from cos-docs.
- **D-03:** Failure handling: **continue on failure, summarize at end.** The wrapper logs per-repo failures (scaffold errors, build errors) and prints a final summary listing failed repos. No auto-rollback; the user fixes failures by hand and re-runs against the targeted repo (or via `--force`).
- **D-04:** Per-repo smoke test: the wrapper runs `mkdocs build --strict` inside each repo (after `pip install -r requirements-docs.txt` in a per-repo venv) before moving on. Aligns with Phase 2 success criterion #5.

**Content Sourcing**
- **D-05:** **Hand-author per repo.** No LLM-assisted bulk drafting. Maintainer reads each repo's `README.md` + `CLAUDE.md` and writes the three docs files directly. Phase 2 is a sustained editorial effort, not a script-driven sweep — `scaffold-all.sh` handles scaffold/commit/build mechanics; humans write the prose.
- **D-06:** `docs/index.md` content target (matches CONT-02 literally): purpose + language/runtime + entry points + key commands. Pull purpose from README intro; lang/runtime from `pyproject.toml` / `package.json`; entry points from CLAUDE.md or the repo's `__main__.py` / `main.py` / `cli`; key commands from README install/run sections.
- **D-07:** `docs/api.md` content (Python repos only): keep auto-generated `::: <package_name>` block from Phase 1 D-12, then add a hand-curated list of important submodules rendered explicitly (e.g. `::: cos_core.models.market`, `::: cos_core.adapters.btc_forge`). Submodule list is per-repo, drawn from the module breakdown in each repo's CLAUDE.md.

**Architecture Diagrams (DIAG-02)**
- **D-08:** **Skip diagrams for trivial / docs-only repos.** Explicit deviation from DIAG-02. Exempt list hardcoded in `scaffold-all.sh` for visibility. DIAG-02 needs amendment in REQUIREMENTS.md to read "per non-exempt repo".
- **D-09:** Diagram-exempt repos (initial): `COS-Hardware`, `COS-Network`, `COS-Capability-Gated-Agent-Architecture`. Any other repo flagged at authoring time goes into the exempt list before commit.
- **D-10:** Diagram level for non-exempt repos: author-chosen mix — module/component graph for libraries, data-flow for pipeline repos, both for service repos. Match the level of detail in `/home/btc/github/CLAUDE.md`.

**Repo Coverage & Scope**
- **D-11:** Authoritative repo list = the project-map table in `/home/btc/github/CLAUDE.md`, taken verbatim (~25 rows). Each row maps to one wrapper iteration. No additional curation.
- **D-12:** Duplicate handling: keep `COS-Capability-Gated-Agent-Architecture` (PascalCase); explicitly exclude the lowercase `capability-gated-agent-architecture` duplicate from the rollout list. Document the exclusion in `scaffold-all.sh`.
- **D-13:** Repo-type behavior inherited from Phase 1: `pyproject.toml` → python (gets `docs/api.md`), `package.json` → ts (no api.md), neither → docs-only (no api.md). Mixed = python primary (Phase 1 D-10).

### Claude's Discretion
- Bash style of `scaffold-all.sh` (associative arrays vs parallel arrays for exempt list; per-repo venv via `python -m venv` vs `uv venv`) — implementer's choice.
- Build-test parallelism (sequential vs `xargs -P N`) — sequential is simpler; planner may parallelize if too slow.
- Whether `scaffold-all.sh` accepts `--only <repo>` for re-running a single failed repo — planner can add if useful, not required.
- Final summary format (tabular vs JSON vs both) — implementer's choice.

### Deferred Ideas (OUT OF SCOPE)
- LLM-assisted bulk drafting of per-repo content — explicitly rejected (D-05).
- A `--only <repo>` flag — planner discretion.
- Parallel execution of the per-repo build-test loop — planner discretion; sequential default.
- Per-page mkdocstrings options heavier than D-07's curated submodule list — left to per-repo authoring judgment.
- Filling diagrams for D-09 exempt repos — not in v1.
- Resolving the `capability-gated-agent-architecture` lowercase duplicate at filesystem level (deleting/merging it) — out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONT-01 | All ~25 sibling repos in `/home/btc/github/` are scaffolded | Per-repo inventory below identifies actual rollout set (29 in-scope, after D-12 exclusion); wrapper design covers per-repo invocation. |
| CONT-02 | Each repo's `docs/index.md` summarizes purpose, language/runtime, entry points (from README + CLAUDE.md) | Inventory column "CLAUDE.md present" identifies which repos have ready source material; 5 repos lack CLAUDE.md and need README-only authoring. |
| CONT-03 | Each repo's `docs/architecture.md` contains a Mermaid diagram + written overview | D-08/D-09 exempt list (3 repos) deviates from "every repo"; DIAG-02 amendment task captured below. Inventory shows 0 repos have pre-existing Mermaid in CLAUDE.md/README — all diagrams will be hand-authored from scratch. |
| CONT-04 | Each Python repo's `docs/api.md` exposes primary public API surface via `mkdocstrings[python]` | Phase 1 D-12 already auto-generates `::: <pkg>` block; D-07 adds hand-curated submodule list. Per-repo `[project].name` already extracted (table below) — no surprises. **Risk:** repos with import-time side effects (CIE, BTE, etc.) may fail `mkdocs build --strict` until their package is `pip install -e .`'d into the per-repo doc venv. |
| DIAG-02 | At least one Mermaid architecture diagram exists per repo | **Amendment required** per D-08: change "per repo" → "per non-exempt repo". Plan must include a task to update REQUIREMENTS.md DIAG-02 wording before phase sign-off. |
</phase_requirements>

## Architectural Responsibility Map

Phase 2 spans two architectural tiers: the wrapper script (cos-docs side) and the per-repo doc trees (sibling-repo side). Hand-authoring is a third "tier" (human editor).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Iterate sibling repos and shell out to `scaffold.sh` | cos-docs/scripts (`scaffold-all.sh`) | — | Wrapper lives in cos-docs; consistent with Phase 1 location of `scaffold.sh`. |
| Per-repo venv + `pip install -r requirements-docs.txt` | cos-docs/scripts (`scaffold-all.sh`) | per-repo `requirements-docs.txt` (Phase 1 deliverable) | Wrapper creates ephemeral venv; pin file is owned by Phase 1 scaffold. |
| Per-repo `mkdocs build --strict` smoke gate | cos-docs/scripts (`scaffold-all.sh`) | per-repo `mkdocs.yml` (Phase 1 deliverable) | Wrapper invokes; correctness depends on Phase 1 template. |
| Per-repo git add/commit/push | sibling-repo `.git/` (each its own repo) | wrapper drives | Each sibling repo is independent — wrapper must `cd` into each. **Tier collision:** wrapper executes git operations on a different repo's history. |
| Hand-author `docs/index.md`, `docs/architecture.md`, `docs/api.md` | Human editor | per-repo `README.md` + `CLAUDE.md` (source material) | D-05 explicitly assigns this to the maintainer. Wrapper does NOT touch user-owned `docs/*.md` after first scaffold. |
| Diagram-exempt enforcement | cos-docs/scripts (`scaffold-all.sh` exempt list) | REQUIREMENTS.md (DIAG-02 amendment) | Exempt list is a code constant; requirements-doc amendment is a separate task. |
| REQUIREMENTS.md DIAG-02 amendment | cos-docs/.planning/ | — | Pure planning-doc edit; one task in the plan. |

**Sanity check for planner:** the wrapper does NOT belong inside `scaffold.sh` (Phase 1 D-04 explicitly forbids batch mode there). The wrapper does NOT run `pip install` into a system Python — it MUST use a per-repo ephemeral venv to avoid polluting the host. The wrapper does NOT auto-commit user-owned `docs/*.md` content (those are still empty stubs at scaffold time; D-05 says humans fill them later, possibly in a separate session — see "Hand-Authoring Workflow Coordination" below).

## Standard Stack

This phase adds **no new runtime dependencies** beyond what Phase 1 already pinned. Tools the wrapper invokes:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | system (5.x on Linux Mint/Ubuntu) | Wrapper script language | [VERIFIED: `/home/btc/github/cos-docs/scripts/scaffold.sh` already uses `#!/usr/bin/env bash` + `set -euo pipefail`] — match Phase 1 style. |
| Python 3.11+ | 3.12.3 system | Per-repo doc-build venv | [VERIFIED: `python3 --version` → 3.12.3] — meets PROJECT.md "Python: 3.11+" constraint and Phase 1 venv assumption. |
| `uv` 0.10.2 | system | Fast venv + pip replacement | [VERIFIED: `uv --version` → 0.10.2; workspace-wide standard per CLAUDE.md "uv is primary Python package manager"]. Use `uv venv .venv-docs && uv pip install -r requirements-docs.txt` — ~10× faster than `python -m venv` + `pip install` across 25+ repos. |
| `mkdocs` (via per-repo venv) | per-repo `requirements-docs.txt` | `mkdocs build --strict` smoke gate | [VERIFIED: Phase 1 D-16 pins `mkdocs-material==9.7.6` which transitively installs `mkdocs` core]. Smoke-tested in Plan 01-02 against COS-Core. |
| `git` | system | Per-repo commit | [VERIFIED: every sibling subdir has `.git/`]. |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `tee` | Capture per-repo build output to log file AND echo to stderr | Debugging failed repos without losing the live progress feedback. |
| `mktemp -d` | Per-iteration scratch for venv if not using fixed `.venv-docs` | If keeping venvs ephemeral (delete after each repo). Trade-off: faster cold cache vs slower per-iteration install. |
| `printf` | Greppable summary lines | Per CONTEXT.md "Specifics" — one-line-per-repo, status code, short reason. Use `printf '%-50s %s %s\n'` for column alignment. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `uv venv` | `python -m venv` | Stdlib-only, no extra dep — but ~5-10× slower across 25+ repos (~30s vs ~3s per venv create + pip install). [ASSUMED] uv is workspace-standard, so use it. |
| Sequential loop | `xargs -P 4` parallelism | Faster wall-clock, but interleaved output is unreadable; `pip install` rate-limit risk; venv creation contention. CONTEXT.md "Claude's Discretion" allows it but defaults sequential — recommend **stick with sequential** until proven too slow (full sweep estimate: ~25 repos × ~30s = ~12 min, acceptable). |
| Per-repo ephemeral venv | One shared `.venv-docs-shared/` reused across repos | Shared venv breaks D-15's repo-independence promise (different repos may have different pinned versions in future, even if today they're all identical). Use ephemeral. |
| Bash loop | Python script | More legible, easier error handling — but introduces a language switch from Phase 1's bash convention and adds a Python dep on the host (we already have python3, but the bash style is workspace-consistent per Phase 1 CONTEXT.md "Established Patterns"). Keep bash. |

**Installation:** None — all tooling already present on workstation. [VERIFIED: `which uv`, `python3 --version`, `git --version` all succeed.]

**Version verification (already done in Phase 1):**
```
mkdocs-material: 9.7.6 [VERIFIED: PyPI dry-run, Plan 01-02 commit 350edac]
mkdocs-monorepo-plugin: 1.1.2 [VERIFIED: same]
mkdocstrings[python]: 1.0.4 [VERIFIED: same]
griffe-pydantic: 1.3.1 [VERIFIED: same]
```
No re-verification needed for Phase 2 — the wrapper installs from the same `requirements-docs.txt` that scaffold.sh emits.

## Architecture Patterns

### System Architecture Diagram

```
                              cos-docs/scripts/scaffold-all.sh (wrapper, NEW)
                                              │
              ┌───────────────────────────────┼─────────────────────────────────┐
              │                               │                                 │
       1. ITERATE                       2. PER-REPO                       3. SUMMARIZE
       ROLLOUT_LIST                     ITERATION                         (D-03)
       (hardcoded array,                (for each repo):                  ┌────────────┐
       D-11 + D-12                      ┌─────────────────────┐           │ stdout:    │
       reconciled with                  │  pre-flight         │           │ table per  │
       actual disk —                    │  - dir exists?      │           │ repo, exit │
       see "Repo                        │  - on main? (D-02)  │           │ status,    │
       Inventory"                       │  - clean tree?      │           │ short      │
       below)                           │  → skip with reason │           │ reason     │
              │                         └─────────┬───────────┘           └────────────┘
              │                                   │
              │                         ┌─────────▼───────────┐
              │                         │  invoke Phase 1     │
              │                         │  scaffold.sh        │ ──fail──> log + continue
              │                         │  /path/to/repo      │
              │                         └─────────┬───────────┘
              │                                   │ pass
              │                         ┌─────────▼───────────┐
              │                         │  uv venv .venv-docs │
              │                         │  uv pip install -r  │ ──fail──> log + continue
              │                         │  requirements-      │
              │                         │  docs.txt           │
              │                         └─────────┬───────────┘
              │                                   │ pass
              │                         ┌─────────▼───────────┐
              │                         │  mkdocs build       │
              │                         │  --strict           │ ──fail──> log + continue
              │                         │  (cwd=repo)         │   (D-04 smoke gate)
              │                         └─────────┬───────────┘
              │                                   │ pass
              │                         ┌─────────▼───────────┐
              │                         │  git add docs/      │
              │                         │  mkdocs.yml         │
              │                         │  requirements-      │ ──fail──> log + continue
              │                         │  docs.txt           │   (e.g., dirty tree
              │                         │  git commit -m ...  │    blocking add)
              │                         │  (cwd=repo, D-02)   │
              │                         └─────────┬───────────┘
              │                                   │ pass
              └───────────────────────────────────┴───> next repo

  HUMAN STEP (out of wrapper, per D-05):
    - For each scaffolded repo, edit docs/index.md, docs/architecture.md,
      docs/api.md by hand using README.md + CLAUDE.md as source material.
    - Re-commit content edits per repo (separate commit from wrapper-driven
      scaffold commit). Wrapper does NOT block waiting for content.
```

Component responsibilities:

| File | Owner | Purpose |
|------|-------|---------|
| `cos-docs/scripts/scaffold-all.sh` | NEW (Phase 2) | Wrapper iteration, pre-flight, smoke gate, summary |
| `cos-docs/scripts/scaffold.sh` | Phase 1 (no edits) | Single-repo file emission |
| `<repo>/docs/index.md` | Human (D-05) | Hand-authored content, scaffold writes stub once |
| `<repo>/docs/architecture.md` | Human (D-05) | Hand-authored Mermaid + prose |
| `<repo>/docs/api.md` | Human (D-05, D-07) | Curated `:::` blocks, scaffold writes auto-block once |
| `<repo>/mkdocs.yml` | Phase 1 scaffold (overwritable) | Per-repo nav + plugin config |
| `<repo>/requirements-docs.txt` | Phase 1 scaffold (overwritable) | Pinned doc-build deps |

### Recommended Project Structure

```
cos-docs/
├── scripts/
│   ├── scaffold.sh          # Phase 1 — single-repo (DO NOT EDIT in Phase 2)
│   └── scaffold-all.sh      # Phase 2 — NEW wrapper
└── .planning/
    └── phases/02-content-migration/
        ├── 02-CONTEXT.md
        ├── 02-DISCUSSION-LOG.md
        └── 02-RESEARCH.md   # this file
```

### Pattern 1: Per-Repo Pre-Flight Check
**What:** Before invoking scaffold.sh on a repo, verify the repo is in a state where the wrapper can safely act.
**When to use:** First step of every per-repo iteration.
**Example (sketch):**
```bash
# Source: workspace bash convention + this research's filesystem audit
preflight() {
    local repo_path="$1"
    [ -d "$repo_path" ]              || { echo "skip: missing"; return 1; }
    [ -d "$repo_path/.git" ]         || { echo "skip: not a git repo"; return 1; }
    local branch
    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
        echo "skip: on branch '$branch' (D-02 expects main)"
        return 1
    fi
    if [ -n "$(git -C "$repo_path" status --porcelain)" ]; then
        echo "skip: dirty working tree (uncommitted changes present)"
        return 1
    fi
    return 0
}
```
**Why:** Phase 2 inventory shows 8 of 31 repos are not on `main`, and 14 of 31 have uncommitted changes. Without pre-flight, D-02's "commit on main" silently commits to a feature branch or interleaves with unrelated WIP.

### Pattern 2: Continue-on-Failure with Status Capture
**What:** Each per-repo step returns a status code; the wrapper records it and moves on (D-03).
**When to use:** Every step inside the per-repo iteration.
**Example (sketch):**
```bash
declare -A REPO_STATUS  # repo → "OK" | "FAIL: <step>: <reason>"
for repo in "${ROLLOUT_LIST[@]}"; do
    if ! preflight "$repo"; then
        REPO_STATUS["$repo"]="SKIP: preflight"
        continue
    fi
    if ! "$SCAFFOLD_SH" "$repo" 2>"$LOG_DIR/$repo.scaffold.log"; then
        REPO_STATUS["$repo"]="FAIL: scaffold (see log)"
        continue
    fi
    if ! build_smoke "$repo" 2>"$LOG_DIR/$repo.build.log"; then
        REPO_STATUS["$repo"]="FAIL: mkdocs build (see log)"
        continue
    fi
    if ! commit_scaffold "$repo"; then
        REPO_STATUS["$repo"]="FAIL: git commit"
        continue
    fi
    REPO_STATUS["$repo"]="OK"
done
```

### Pattern 3: Ephemeral Per-Repo Venv
**What:** Create a fresh `.venv-docs/` inside each repo, install pinned deps, run `mkdocs build --strict`, optionally clean up.
**Example:**
```bash
build_smoke() {
    local repo_path="$1"
    (
        cd "$repo_path" || exit 1
        uv venv --quiet .venv-docs >/dev/null 2>&1 || return 1
        uv pip install --quiet --python .venv-docs/bin/python \
            -r requirements-docs.txt >/dev/null 2>&1 || return 1
        # For Python repos, install the package itself so mkdocstrings can import it
        if [ -f pyproject.toml ]; then
            uv pip install --quiet --python .venv-docs/bin/python -e . >/dev/null 2>&1 \
                || echo "warn: pip install -e . failed, mkdocstrings may not resolve" >&2
        fi
        .venv-docs/bin/mkdocs build --strict
    )
}
```
**Why pip-install the repo itself:** Plan 01-02 verified mkdocs needs the package importable to render `::: <pkg>`. For COS-Core that meant `pip install -e .` after the doc deps. The wrapper must replicate this for every Python repo, OR the smoke gate will pass trivially (mkdocstrings emits a warning, not a `--strict` error, when a `:::` target can't import — **need to verify this**, see Open Question 1 below).

### Pattern 4: Decoupled Hand-Authoring
**What:** Wrapper finishes at "scaffold + smoke + commit-empty-stubs". Humans fill content later, in any order, with separate commits per repo.
**Example workflow:**
1. Maintainer runs `scaffold-all.sh` once. Result: 25 commits across 25 repos saying `docs: add cos-docs scaffold + initial content` — but `docs/*.md` is still the Phase 1 stub template at this point.
2. Maintainer picks one repo (e.g. COS-Core), opens `docs/index.md`, writes real content, commits separately as `docs: populate index/architecture/api content`.
3. Repeat per repo over a sustained editorial period (D-05).
**Tradeoff:** The first commit is technically misleading ("initial content" but content is just stubs). Mitigation: change commit message to `docs: scaffold cos-docs templates (content to follow)` to honestly describe the state.

### Anti-Patterns to Avoid
- **Single mega-commit across all repos:** Each sibling repo is its own git repo (no monorepo tooling, per CLAUDE.md). One commit per repo is the only correct unit.
- **Auto-switching branches:** Don't run `git checkout main` inside a sibling repo — the user may have unfinished WIP on the current branch. Pre-flight should SKIP, not silently switch.
- **Auto-stashing dirty changes:** Stash → scaffold → unstash is a foot-gun if the build smoke fails midway. Skip dirty repos entirely; let the user resolve.
- **Reusing one shared venv across repos:** Breaks D-15's repo-independence (per-repo `requirements-docs.txt` is canonical for each repo's local preview).
- **Polluting host Python with `pip install`:** Always use `uv venv` or `python -m venv`.
- **Quiet failures:** Every failure must print a one-line summary AND retain a per-repo log file path. CONTEXT.md "Specifics" requires greppable output.
- **Coupling wrapper to hand-authoring:** Don't have the wrapper wait for content to exist before committing. D-05 + Phase 1 D-05 user-ownership are explicit: scaffold writes stubs, humans fill later, separate commits.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Repo iteration with arrays | Custom assoc-array DSL | Plain bash array `ROLLOUT_LIST=( /path/a /path/b ... )` | Bash arrays are well-understood; assoc arrays only needed if you want per-repo metadata (exempt? skip-build?). |
| Per-repo venv | `python -m venv` from scratch | `uv venv` | Workspace standard; ~10× faster. |
| TOML parsing for `[project].name` | New parser | Reuse Phase 1's `sed -nE` extractor | Already proven on COS-Core; lives in `scaffold.sh:97-109`. Wrapper doesn't need to re-parse. |
| Diff output for git | Custom diff renderer | `git diff` / `git status --porcelain` | Standard. |
| Idempotency | Per-file checksum tracking | Phase 1's user-owned vs scaffold-owned split (D-05/D-06) is already correct | Don't reinvent — wrapper inherits this for free. |
| `mkdocs build` strictness | Custom HTML validator | `mkdocs build --strict` | Built-in flag treats warnings as errors; it's exactly the smoke gate D-04 wants. |

**Key insight:** Phase 1 already paid the complexity tax for emit/diff/idempotency. Phase 2's wrapper is a 60-100 line bash loop — anything more than that suggests scope creep into territory Phase 1 already owns.

## Runtime State Inventory

Phase 2 is **not a rename/refactor/migration phase** — it is a brownfield content rollout that adds new files to ~25 sibling repos. No existing runtime state needs migrating. Section omitted per the "Greenfield phases" exclusion.

The closest analog is "what gets added to each sibling repo's git history" — but that's covered by D-02's commit strategy, not by runtime-state migration.

## Repo Inventory (CRITICAL — answers CONT-01)

This is the most important deliverable of Phase 2 research. The CONTEXT.md D-11 "verbatim from CLAUDE.md project map" cannot be applied as-is — the project map is **stale relative to disk**.

[VERIFIED: `ls -la /home/btc/github/`, per-repo `[ -f pyproject.toml ]`, `[ -f package.json ]`, `[ -f README.md ]`, `[ -f CLAUDE.md ]`, `[ -d docs ]`, `git rev-parse --abbrev-ref HEAD`, `git status --porcelain` — all run 2026-04-19.]

### Full Disk Inventory (31 git repos in `/home/btc/github/`)

Legend: **PY**=pyproject.toml present (Python primary, gets api.md per D-13). **TS**=package.json present. **R**=README.md. **C**=CLAUDE.md. **D**=existing `docs/` dir. **MK**=existing `mkdocs.yml`. **Branch**=current HEAD. **Dirty**=uncommitted file count. **In CLAUDE.md project map?**

| # | Repo (disk path) | PY | TS | R | C | D | MK | Branch | Dirty | In Map? | Action |
|---|------------------|----|----|---|---|---|----|--------|-------|---------|--------|
| 1 | `bis-forge` | ✓ | — | ✓ | ✓ | — | — | main | 3 | ✓ | scaffold; **resolve dirty first** |
| 2 | `bls-forge` | ✓ | — | ✓ | ✓ | — | — | main | 3 | ✓ | scaffold; **resolve dirty first** |
| 3 | `BTC-Forge` | ✓ | — | ✓ | ✓ | — | — | main | 1 | ✓ | scaffold; **resolve dirty first** |
| 4 | `capability-gated-agent-architecture` | — | — | ✓ | ✓ | — | — | main | 0 | ✓ (lowercase dup) | **EXCLUDE per D-12** |
| 5 | `coinbase_websocket_BTC_pricefeed` | — | — | ✓ | — | — | — | **kubernetes** | 0 | ✓ | scaffold; **branch ≠ main, decide policy** |
| 6 | `COS-Bitcoin-Protocol-Intelligence-Platform` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✓ | scaffold; ready |
| 7 | `COS-BTC-Network-Crawler` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✓ | scaffold; ready |
| 8 | `COS-BTC-Node` | — | — | — | ✓ | — | — | main | 1 | ✗ (was `bitcoin_node` in map) | **map mismatch — add to rollout as docs-only**; resolve dirty first |
| 9 | `COS-BTC-SQL-Warehouse` | ✓ | — | ✓ | ✓ | **✓** | — | main | 1 | ✓ | scaffold; **existing docs/ contains `spec_v1.2.md` — coexists** |
| 10 | `COS-BTE` | ✓ | — | ✓ | ✓ | — | — | main | 2 | ✓ | scaffold; resolve dirty first |
| 11 | `COS-Capability-Gated-Agent-Architecture` | — | — | ✓ | — | — | — | **spec-decomposition-extraction** | 2 | ✓ | scaffold (docs-only, **D-09 exempt**); **branch ≠ main + dirty** |
| 12 | `COS-CIE` | ✓ | — | — | ✓ | — | — | **master** | 0 | ✓ | scaffold; **branch=master not main** |
| 13 | `cos-data-access` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✗ | **map mismatch — add to rollout as Python** |
| 14 | `cos-docs` | — | — | ✓ | — | — | — | main | 0 | ✗ (this repo) | **EXCLUDE — this is the aggregator itself** |
| 15 | `COS-electrs` | — | — | ✓ | ✓ | — | — | new-index | 3 | ✗ | **Rust repo (Cargo.toml only); decide: docs-only scaffold or exclude entirely** |
| 16 | `COS-Hardware` | — | — | ✓ | — | — | — | main | 3 | ✓ | scaffold (docs-only, **D-09 exempt**); resolve dirty first |
| 17 | `COS-Infra` | — | — | ✓ | ✓ | **✓** | — | **master** | 0 | ✗ | **map mismatch — add to rollout**; existing docs/ has 12 .md files (deployment guides); branch=master |
| 18 | `COS-LangGraph` | ✓ | — | ✓ | ✓ | — | — | **master** | 0 | ✓ | scaffold; **branch=master not main** |
| 19 | `COS-MSE` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✗ | **map mismatch — add to rollout as Python** |
| 20 | `COS-Network` | — | — | ✓ | — | — | — | main | 0 | ✓ | scaffold (docs-only, **D-09 exempt**) |
| 21 | `COS-SGL` | ✓ | — | ✓ | ✓ | — | — | main | 5 | ✓ | scaffold; resolve dirty first |
| 22 | `cos-signal-bridge` | ✓ | — | ✓ | — | — | — | main | 0 | ✓ | scaffold; ready |
| 23 | `cos-signal-explorer` | ✓ | — | ✓ | ✓ | — | — | main | 3 | ✗ | **map mismatch — add to rollout as Python**; resolve dirty first |
| 24 | `cos-webpage` | — | ✓ | ✓ | ✓ | — | — | main | 1 | ✗ | **map mismatch — add to rollout as TS** (no api.md per D-11); resolve dirty first |
| 25 | `EDGAR-Forge` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✓ (was `edgar-forge`) | **case mismatch in map**; scaffold; ready |
| 26 | `FRED-Forge` | ✓ | — | ✓ | ✓ | — | — | main | 0 | ✓ (was `fred-forge`) | **case mismatch in map**; scaffold; ready |
| 27 | `imf-forge` | ✓ | — | ✓ | ✓ | — | — | main | 2 | ✓ | scaffold; resolve dirty first |
| 28 | `ingest` | ✓ | — | ✓ | — | — | — | main | 0 | ✓ | scaffold; ready |
| 29 | `OrbWeaver` | — | — | ✓ | — | — | — | **kubernetes** | 4 | ✓ | scaffold (docs-only — has README only, no pyproject.toml on this branch); **branch ≠ main + dirty** |
| 30 | `quant-dashboard` | — | ✓ | ✓ | ✓ | **✓** | — | **kubernetes** | 33 | ✓ | scaffold (TS, no api.md per D-11); existing docs/ has 2 .md files; **branch ≠ main + heavy dirty** |
| 31 | `stooq-forge` | ✓ | — | ✓ | ✓ | — | — | main | 1 | ✗ | **map mismatch — add to rollout as Python**; resolve dirty first |

### Reconciliation Summary

**CLAUDE.md project map says ~25; actual disk has 31 git repos.**

**In map but missing/renamed on disk** (must reconcile before wrapper iteration):
- `fred-forge` → actual is `FRED-Forge` (PascalCase)
- `edgar-forge` → actual is `EDGAR-Forge` (PascalCase)
- `bitcoin_node` → actual is `COS-BTC-Node`
- All other map entries match disk

**On disk but NOT in CLAUDE.md project map** (decision needed: include or exclude):
- `cos-data-access` (Python; recommend INCLUDE — has pyproject + README + CLAUDE.md, ready)
- `COS-Infra` (docs/scripts; recommend INCLUDE — has CLAUDE.md, but check existing docs/ collision)
- `COS-MSE` (Python; recommend INCLUDE — Market Sentiment Engine, has full pyproject + CLAUDE.md, ready)
- `cos-signal-explorer` (Python; recommend INCLUDE)
- `cos-webpage` (TS; recommend INCLUDE — only TS-primary repo besides quant-dashboard)
- `COS-electrs` (Rust; recommend EXCLUDE or scaffold as docs-only — Phase 1 has no Rust path; D-13 falls through to docs-only since no `pyproject.toml` and no `package.json`, but the result is misleading)
- `COS-BTC-Node` (docs-only; recommend INCLUDE as docs-only — has CLAUDE.md)
- `stooq-forge` (Python; recommend INCLUDE — completes the forge family)
- `cos-docs` itself (recommend EXCLUDE — this is the aggregator, scaffolding it would be circular)

**Strict CONTEXT.md D-11 application would scaffold ~25 repos and miss 6 that exist and have content. Recommend planner amend D-11 to "use the actual disk inventory, with CLAUDE.md project map as a starting point that needs sync." Add a task to the plan to update CLAUDE.md project map to match disk reality after the rollout.**

### Final Recommended Rollout Set

**29 repos in scope** (after excluding `capability-gated-agent-architecture` per D-12 and `cos-docs` self-reference):

- **20 Python** (get docs/api.md): bis-forge, bls-forge, BTC-Forge, COS-Bitcoin-Protocol-Intelligence-Platform, COS-BTC-Network-Crawler, COS-BTC-SQL-Warehouse, COS-BTE, COS-CIE, cos-data-access, COS-LangGraph, COS-MSE, COS-SGL, cos-signal-bridge, cos-signal-explorer, EDGAR-Forge, FRED-Forge, imf-forge, ingest, stooq-forge, **plus** COS-Core (already verified Phase 1 — but should be re-included in the rollout for consistency)
- **2 TypeScript** (no api.md): cos-webpage, quant-dashboard
- **6 docs-only**: coinbase_websocket_BTC_pricefeed, COS-BTC-Node, COS-Capability-Gated-Agent-Architecture (exempt), COS-Hardware (exempt), COS-Infra, COS-Network (exempt), OrbWeaver
- **1 special-case**: COS-electrs (Rust) — planner decides include-as-docs-only or exclude
- **3 D-09 diagram-exempt**: COS-Hardware, COS-Network, COS-Capability-Gated-Agent-Architecture (per CONTEXT.md)

(Count audit: 20 + 2 + 6 + 1 = 29. Including/excluding electrs and COS-Core toggles between 28 and 30. Planner picks.)

### Source-Material Readiness

[VERIFIED: per-repo `[ -f CLAUDE.md ]` and `[ -f README.md ]`]

| Has both README + CLAUDE.md | Count | Notes |
|----|-------|-------|
| Both present | 22 | Ready for D-05 hand-authoring with full source material |
| README only (no CLAUDE.md) | 7 | Reduced source material — hand-author from README + code skim. Repos: `coinbase_websocket_BTC_pricefeed`, `cos-docs`, `COS-Capability-Gated-Agent-Architecture`, `COS-Hardware`, `COS-Network`, `cos-signal-bridge`, `ingest`, `OrbWeaver` |
| CLAUDE.md only (no README) | 2 | Surprising: `COS-BTC-Node`, `COS-CIE` lack a README.md. Hand-author primarily from CLAUDE.md. |
| Neither | 0 | (Good — every repo has at least one source file.) |

### Pre-Existing Mermaid Diagrams (D-10 portability check)

[VERIFIED: `grep -l '```mermaid' **/CLAUDE.md` returned NO matches]

**Zero repos have pre-existing Mermaid diagrams in their CLAUDE.md or README.md.** All Phase 2 architecture diagrams will be hand-authored from scratch (D-10), drawing on the prose architecture descriptions in CLAUDE.md but with no diagram-source-code to port. This is **more work** than CONTEXT.md's "match the level of detail in `/home/btc/github/CLAUDE.md`" implies — the workspace CLAUDE.md uses prose + ASCII, not Mermaid.

### Pre-Existing `docs/` Trees (Phase 1 D-07 collision check)

[VERIFIED: `[ -d docs ]` per repo]

**Three repos have pre-existing `docs/` directories** (Phase 1 D-07 assumed zero collision risk because no `mkdocs.yml` exists in any sibling — that part holds, but the `docs/` directory itself coexists):

| Repo | Existing files in docs/ | Collision risk |
|------|-------------------------|----------------|
| `COS-BTC-SQL-Warehouse/docs/` | `spec_v1.2.md` (135 KB) | LOW — Phase 1 scaffold writes `index.md`, `architecture.md`, `api.md`. No name collision. The existing `spec_v1.2.md` will simply not appear in nav (Phase 1 mkdocs.yml nav is fixed 3-page). Maintainer can add a 4th nav entry post-scaffold if desired. |
| `COS-Infra/docs/` | 12 deployment-guide .md files | LOW — same as above; no name collision. May want to expand nav to expose them. |
| `quant-dashboard/docs/` | `FRED_DEPLOYMENT.md`, `FRED_INTEGRATION_COMPLETE.md` | LOW — same. |

**Phase 1 D-07 "no pre-existing mkdocs.yml" assumption holds** (verified across all 31 repos: zero `mkdocs.yml`). The pre-existing `docs/` directories are non-blocking.

## `mkdocs build --strict` Per-Repo Failure Modes (CRITICAL)

This is the single highest-risk technical area in Phase 2. Phase 1 verified the smoke gate works on **one** repo (COS-Core, which is well-behaved: pure-Python, no import-time side effects, cleanly defined `[project].name`). The other 19 Python repos vary widely in import behavior.

### Failure Mode 1: Missing `[project].name` → Falls back to directory name

[VERIFIED: scaffold.sh:97-109 falls back to `basename` then hyphen→underscore]

| Repo | `[project].name` | Falls back to (if name absent) | Risk |
|------|------------------|-------------------------------|------|
| All 19 Python repos in scope | All have a name set (see table below) | n/a | **NONE** — verified every Python repo's pyproject.toml has `[project].name` populated. |

[VERIFIED: per-repo `sed -nE` extraction across all repos with pyproject.toml]

```
bis-forge                                          name=bis-forge
bls-forge                                          name=bls-forge
BTC-Forge                                          name=btc-ohlcv-forge
COS-Bitcoin-Protocol-Intelligence-Platform         name=bpip
COS-BTC-Network-Crawler                            name=crawl-arch
COS-BTC-SQL-Warehouse                              name=btc-warehouse
COS-BTE                                            name=cos-bte
COS-CIE                                            name=cos-cie
cos-data-access                                    name=cos-data-access
COS-LangGraph                                      name=cos-langgraph
COS-MSE                                            name=market-sentiment-engine
COS-SGL                                            name=xuer-sgl
cos-signal-bridge                                  name=cos-signal-bridge
cos-signal-explorer                                name=cos-signal-explorer
EDGAR-Forge                                        name=edgar-forge
FRED-Forge                                         name=fred-forge
imf-forge                                          name=imf-forge
ingest                                             name=ingest
stooq-forge                                        name=stooq-forge
cos-webpage                                        name=<none>  ← TS repo, no api.md, irrelevant
```

**Key observation:** the `[project].name` is the **distribution name**, NOT necessarily the importable module name. After D-13's hyphen→underscore normalization:

- `BTC-Forge` → `btc_ohlcv_forge` ← but the actual top-level module on disk under `src/` may be different. Need to verify.
- `COS-Bitcoin-Protocol-Intelligence-Platform` → `bpip` ← `bpip` IS the importable name.
- `COS-BTC-Network-Crawler` → `crawl_arch` ← need to verify this matches the actual module name.
- `COS-MSE` → `market_sentiment_engine` ← need to verify against `src/`.
- `COS-SGL` → `xuer_sgl` ← [VERIFIED: `ls COS-SGL/src` shows `xuer_sgl/` — match]

[VERIFIED partial: `ls -d <repo>/src/*/`]:
- `COS-Core/src/cos_core/` ✓ matches `cos-core` → `cos_core`
- `COS-LangGraph/src/langgraph_agent/` ✗ does NOT match `cos-langgraph` → `cos_langgraph`. **MISMATCH**.
- `COS-BTE/src/cos_bte/` ✓ matches
- `COS-SGL/src/xuer_sgl/` ✓ matches
- `COS-BTC-SQL-Warehouse/src/btc_warehouse/` ✓ matches

**COS-LangGraph is a known mismatch:** distribution name `cos-langgraph` → fallback module `cos_langgraph` — but actual src module is `langgraph_agent`. The `::: cos_langgraph` directive will fail to resolve, mkdocstrings will emit a warning, `mkdocs build --strict` will fail.

**Implication for Phase 2 plan:** A Phase 1-or-Phase-2 fix is needed: either (a) Phase 1's `detect_python_package` reads from `[tool.hatch.build.targets.wheel].packages` or actually scans `src/` for the top-level package, or (b) Phase 2's wrapper accepts a per-repo override map for the package name. Recommend option (b) — keep Phase 1 scaffold.sh as-is, add a `PACKAGE_OVERRIDES` associative array in `scaffold-all.sh` for the known mismatches, and pass an override flag (a new `--package <name>` for scaffold.sh, OR have scaffold-all.sh do a post-scaffold sed on the generated `docs/api.md`).

[ASSUMED] Other potential mismatches that need verification at plan time: `COS-Bitcoin-Protocol-Intelligence-Platform` (`bpip` may match), `COS-BTC-Network-Crawler` (`crawl_arch` may not match a module called `cos_crawler` or similar), `BTC-Forge` (`btc_ohlcv_forge`), `COS-MSE` (`market_sentiment_engine`). Plan task: run `python -c "import <name>"` per repo in its venv and record actual module name before the wrapper's first sweep.

### Failure Mode 2: Import-Time Side Effects in `__init__.py`

[VERIFIED: per-repo `head -10 src/<pkg>/__init__.py`]

Repos with import-side-effect-free `__init__.py` (just module docstring or empty):
- COS-LangGraph, COS-BTC-SQL-Warehouse, COS-BTE, COS-Bitcoin-Protocol-Intelligence-Platform, COS-MSE, COS-Core (verified Phase 1)

Repos with re-export imports in `__init__.py` (will trigger transitive imports at mkdocstrings discovery time):
- **COS-CIE** — imports `composite`, `library`, `models`, `polarity`, `types` at top level. If any of those modules imports a heavy dep (sklearn, statsmodels per CLAUDE.md), and that dep is not installed in the doc venv, mkdocstrings will fail. **HIGH risk** — Phase 2 plan must include `pip install -e .` of the package itself into the doc venv (covered in Pattern 3 above), AND ensure runtime deps (`sklearn`, `statsmodels`) are installed too.

**Implication:** The smoke gate's per-repo venv needs more than just `requirements-docs.txt`. It needs `pip install -e .` (which pulls in the package's runtime deps from its pyproject.toml). The wrapper sketch in Pattern 3 already does this with a warning; **this should be a hard error, not a warning**, to honestly fail the smoke gate.

### Failure Mode 3: TS / docs-only Repos and `--strict` Build

[VERIFIED Phase 1: scaffold.sh skips api.md emission for non-Python; mkdocs.yml conditionally omits the api.md nav line]

For TS repos (`cos-webpage`, `quant-dashboard`) and docs-only repos (`coinbase_websocket_BTC_pricefeed`, `COS-Hardware`, `COS-Network`, etc.):
- Phase 1 emits 2-page nav: Overview + Architecture (no API)
- Phase 1 mkdocstrings plugin block is still in `mkdocs.yml` (no conditional omission)
- **Risk:** mkdocstrings plugin loaded but never invoked — does `mkdocs build --strict` complain? [ASSUMED: NO, the plugin is harmless if no `:::` directives appear in any page. Should verify.] [CITED: https://mkdocstrings.github.io/usage/ — plugin is opt-in per page via `:::`, no `:::` means no rendering attempt.]

Recommend planner verify with one TS repo (cos-webpage) as a pre-flight smoke during Phase 2 implementation. If false, the wrapper needs to emit a stripped-down mkdocs.yml for non-Python repos (which would mean a Phase 1 amendment).

### Failure Mode 4: Pinned Versions vs. Newer Pydantic

[VERIFIED Phase 1: griffe-pydantic 1.3.1 works against COS-Core's Pydantic v2 schemas]

[ASSUMED]: Other Python repos use Pydantic >=2.0 per workspace standard (CLAUDE.md). If any repo pins an older Pydantic v1 (e.g., a legacy fork), griffe-pydantic 1.3.1 may not extract field docs. Quick scan in plan time: `grep -r 'pydantic<2' /home/btc/github/*/pyproject.toml`. If zero matches, this risk is mooted.

### Failure Mode 5: No `src/` Layout (Flat-Layout Repos)

Some Python repos may have a flat `<package>/__init__.py` at the repo root rather than `src/<package>/__init__.py`. mkdocstrings + griffe walk Python paths, not directory structures, so as long as `pip install -e .` succeeds, it works. [VERIFIED: every Python repo in scope has either `src/<pkg>/` or top-level `<pkg>/`; `pip install -e .` resolves either layout.]

## Hand-Authoring Workflow Coordination (D-05)

CONTEXT.md decided "hand-author" but did not specify workflow ergonomics. Research suggests three viable plan structures:

### Option A: One umbrella plan with per-repo subtasks
**Structure:** `02-01-PLAN.md` = wrapper script (10 tasks). `02-02-PLAN.md` = content authoring (one task per repo, ~25-29 tasks).
**Pros:** Single content-authoring plan keeps the rollout state visible in one place. Plan completion = phase completion.
**Cons:** A 25-task plan is unwieldy in GSD's task-status tracking. If half the repos fail authoring, the plan stays "in progress" indefinitely.

### Option B: Per-repo plans (29 plans)
**Structure:** `02-01-PLAN.md` = wrapper. `02-02..02-30` = one plan per repo.
**Pros:** Clean per-repo state tracking. Failures isolate.
**Cons:** Plan-overhead explosion for a phase that is mostly editorial. GSD's planning artifacts become noise.

### Option C: Three plans — wrapper, scaffold-everything, content-pass
**Structure:**
- `02-01-PLAN.md` = author `scaffold-all.sh`, smoke-test against 2-3 ready repos
- `02-02-PLAN.md` = run `scaffold-all.sh` against full rollout list, address per-repo failures, commit scaffold-only state
- `02-03-PLAN.md` = content authoring pass (umbrella, with per-repo checklist as task body)

**Pros:** Separates "mechanical scaffold" (deterministic, automatable) from "editorial content" (open-ended, human-paced). Phase 2 can ship with 02-01 + 02-02 complete and 02-03 partially complete — content authoring continues incrementally without blocking the phase boundary.
**Cons:** Phase 2 success criteria #2 (every index.md has content) requires 02-03 fully complete to satisfy CONT-02.

**Recommendation: Option C.** It matches CONTEXT.md "Specifics" line: *"Per-repo authoring sessions can run independently of the wrapper — D-05 (hand-author) means scaffold-all.sh's job ends at scaffold + build-test; humans pick up from there per repo, in any order."* The plan-checker should not gate phase completion on 02-03 task-by-task; it should gate on the full set of CONT-* requirements being satisfied.

### Wrapper-vs-Content Coexistence

The wrapper writes Phase 1 stub content (the heredocs in scaffold.sh). After scaffold + smoke + commit, each repo contains:
- `docs/index.md` = "# Overview\n\n> Replace this with a one-paragraph summary..."
- `docs/architecture.md` = sample flowchart Mermaid + "> Replace this with a written overview..."
- `docs/api.md` = `::: <pkg>` block (renders real API doc, no replacement needed for v1)

When the maintainer later runs `scaffold.sh --force`, the user-owned `docs/*.md` get overwritten — destroying hand-authored content. **Plan task: document this gotcha in `scaffold-all.sh` usage comment ("never re-run scaffold.sh --force after content authoring begins"), and consider adding a `--no-force` enforcement in the wrapper (don't pass --force through).**

The "is this stub or filled?" detection problem (does the planner need a quality gate?): A simple grep for the literal stub strings (`"Replace this with a one-paragraph summary"`, `"Replace this with a written overview"`) gives an exact "not yet authored" signal. Recommend the plan include a `scaffold-status.sh` helper (or extend `scaffold-all.sh` with a `--status` mode) that scans all rolled-out repos and reports per-repo: stub | partial | filled. This makes the editorial progress visible.

## DIAG-02 Amendment Mechanics

CONTEXT.md D-08 explicitly deviates from REQUIREMENTS.md DIAG-02. The plan must include a task to amend the requirements doc.

**Current DIAG-02 wording** (REQUIREMENTS.md:33):
> - [ ] **DIAG-02**: At least one Mermaid architecture diagram exists per repo (in `docs/architecture.md`)

**Recommended amended wording:**
> - [ ] **DIAG-02**: At least one Mermaid architecture diagram exists per non-exempt repo (in `docs/architecture.md`). Exempt repos (no software architecture to diagram): `COS-Hardware`, `COS-Network`, `COS-Capability-Gated-Agent-Architecture`. Exempt list may grow during Phase 2 authoring; additions are recorded in `cos-docs/scripts/scaffold-all.sh`.

**Where the change lives:** REQUIREMENTS.md line 33 (single line). No traceability table change needed (DIAG-02 stays mapped to Phase 2). PROJECT.md "Per-repo Mermaid diagram + top-level workspace diagram" Key Decisions row (line 71) should also have a footnote referencing the exempt list.

**Plan task:** A single ~5-minute edit to REQUIREMENTS.md + a corresponding row update or footnote in PROJECT.md Key Decisions. Should land before the phase verification step so the phase-checker doesn't flag DIAG-02 as unmet for the 3 exempt repos.

## Common Pitfalls

### Pitfall 1: Stale CLAUDE.md Project Map
**What goes wrong:** Wrapper iterates the CLAUDE.md project map verbatim (D-11), tries to scaffold `fred-forge`/`edgar-forge`/`bitcoin_node`, gets "directory does not exist" errors for 3 repos, silently misses 6+ repos that exist and have content.
**Why it happens:** CONTEXT.md D-11 said "verbatim" without verifying against disk. Workspace evolved since CLAUDE.md was last updated.
**How to avoid:** Build the rollout list from `ls /home/btc/github/` filtered by `[ -d <repo>/.git ]`, with the CLAUDE.md project map as a sanity-check overlay. Plan task: also update CLAUDE.md project map post-rollout to match disk.
**Warning signs:** Wrapper exit code 0 but only 22 repos scaffolded (silent skips); or wrapper hard-fails on first missing dir.

### Pitfall 2: Branch Drift (D-02 Assumption Violated)
**What goes wrong:** Wrapper commits to `master` thinking it's `main`, or commits to a feature branch like `kubernetes` or `spec-decomposition-extraction`, or commits onto someone's WIP, polluting unrelated work.
**Why it happens:** D-02 assumed all repos are on `main`; disk shows 8 repos are not.
**How to avoid:** Pre-flight branch check (Pattern 1). Skip with explicit reason; do NOT auto-switch branches. Surface skipped repos in the final summary so the maintainer can manually scaffold them.
**Warning signs:** Final summary lists `<N> SKIP: branch=<X>` lines.

### Pitfall 3: Dirty-Tree Commit Pollution
**What goes wrong:** `git add docs/ mkdocs.yml requirements-docs.txt && git commit` accidentally bundles unrelated WIP changes into the scaffold commit.
**Why it happens:** Wrapper uses broad `git add` instead of explicit file paths; or doesn't pre-flight for clean tree.
**How to avoid:** Pre-flight clean-tree check; use explicit `git add docs/index.md docs/architecture.md docs/api.md mkdocs.yml requirements-docs.txt` (named files only, no globs); verify `git diff --staged` matches expected before committing. **Never use `git add -A` or `git add .`.**
**Warning signs:** Commit diff includes files outside the scaffold output set.

### Pitfall 4: Module-Name vs Distribution-Name Mismatch
**What goes wrong:** scaffold.sh derives `cos_langgraph` from `[project].name=cos-langgraph` but the actual importable package is `langgraph_agent`. mkdocstrings emits warning, `--strict` fails.
**Why it happens:** PEP 621 `[project].name` is a distribution name; nothing requires it to match the importable module name. Phase 1 conflated them.
**How to avoid:** Plan task: per-Python-repo, run `python -c "import <module>"` once during the wrapper's first sweep and capture the true module name. Use a `PACKAGE_OVERRIDES` map for known mismatches: `["COS-LangGraph"]="langgraph_agent"`. Pass override to scaffold.sh (need new flag) or post-process generated `docs/api.md` via sed.
**Warning signs:** mkdocs build output: `WARNING - mkdocstrings: Could not collect 'cos_langgraph'`.

### Pitfall 5: Doc Venv Missing Runtime Deps
**What goes wrong:** Per-repo doc venv installs `requirements-docs.txt` but not `pip install -e .` of the repo. mkdocstrings tries to import the package; transitive imports fail; warnings; `--strict` fails.
**Why it happens:** Phase 1 D-15 says `requirements-docs.txt` is doc-only deps; running mkdocs in that venv against a `:::` block needs the target package importable too.
**How to avoid:** Wrapper does `uv pip install -e .` after `requirements-docs.txt` for every Python repo. This pulls in the package's pyproject runtime deps automatically. Verified in Phase 1 against COS-Core; must replicate for every repo.
**Warning signs:** `ModuleNotFoundError` in mkdocs build log.

### Pitfall 6: `--force` Re-Run Destroys Hand-Authored Content
**What goes wrong:** After Phase 2 03-content-pass plan partially authors `docs/index.md`, someone re-runs `scaffold-all.sh --force` (e.g., to refresh `mkdocs.yml` after a Phase 3 template tweak); the `--force` propagates to scaffold.sh, which overwrites `docs/index.md` with the stub.
**Why it happens:** scaffold.sh `--force` is sticky: it overwrites both scaffold-owned AND user-owned files. The wrapper has no `--force` semantics today, so anyone adding it would naturally forward it.
**How to avoid:** Wrapper does NOT expose `--force` (pass-through prohibited). If the user wants to refresh scaffold-owned files (mkdocs.yml, requirements-docs.txt), run scaffold.sh directly per-repo without `--force` — D-05/D-06 already overwrites those without touching docs/*.md. **The wrapper has no legitimate use case for `--force` because docs/*.md ownership is user-owned; only Phase 1 single-repo scaffold has the rare "I want to start over" use case.**
**Warning signs:** Lost content in commit history.

### Pitfall 7: COS-electrs (Rust) Edge Case
**What goes wrong:** Wrapper tries to scaffold COS-electrs; D-13 falls through to "docs-only" (no pyproject, no package.json); scaffold succeeds, mkdocs build succeeds, but the resulting page is meaningless prose templates with no API surface representation.
**Why it happens:** Phase 1 D-09 didn't anticipate Rust (Cargo.toml only). Phase 2 hits a previously-unseen repo type.
**How to avoid:** Plan decision: explicitly EXCLUDE COS-electrs from rollout (it's not in CLAUDE.md project map anyway), OR include it as docs-only with a hand-authored architecture page that explains the Rust workspace structure. Recommend EXCLUDE for v1; revisit in v2 if Rust API rendering becomes a need (would require typedoc-equivalent like `cargo doc` integration, which is well outside scope).
**Warning signs:** docs-only page for a Rust repo confuses readers.

### Pitfall 8: COS-Infra and COS-BTC-SQL-Warehouse Existing `docs/` Coexistence
**What goes wrong:** Phase 1 scaffold writes `docs/index.md`, `docs/architecture.md`, `docs/api.md` — but `COS-Infra/docs/` already has 12 deployment-guide .md files that are NOT in the new `mkdocs.yml` nav. Maintainer sees the deployment guides "missing" from the rendered site and assumes the scaffold broke them.
**Why it happens:** Phase 1 mkdocs.yml nav is a fixed 3-entry list, ignoring any other .md files in `docs/`.
**How to avoid:** Plan task: at content-pass time for these repos, expand the nav to include the existing pages, OR document the gotcha in the wrapper's per-repo log output ("note: existing docs/*.md files not added to nav; edit mkdocs.yml to expose them").
**Warning signs:** Site preview missing pages that exist in the repo.

## Code Examples

### Example 1: Wrapper Skeleton (illustrative — planner finalizes)

```bash
#!/usr/bin/env bash
# Source: this research; matches Phase 1 cos-docs/scripts/scaffold.sh style
set -euo pipefail

# scaffold-all.sh — Iterate ROLLOUT_LIST and apply Phase 1's scaffold.sh per repo.
# Per-repo: pre-flight → scaffold → venv+pip → mkdocs build --strict → git commit.
# Continues on per-repo failure (D-03); prints summary table at end.

WORKSPACE="${WORKSPACE:-/home/btc/github}"
SCAFFOLD_SH="$(dirname "$0")/scaffold.sh"
LOG_DIR="$(mktemp -d -t scaffold-all.XXXXXX)"

# D-11 + D-12 + this research's reconciliation. Plan finalizes exact list.
ROLLOUT_LIST=(
    bis-forge bls-forge BTC-Forge
    COS-Bitcoin-Protocol-Intelligence-Platform COS-BTC-Network-Crawler
    COS-BTC-Node COS-BTC-SQL-Warehouse COS-BTE COS-Capability-Gated-Agent-Architecture
    COS-CIE COS-Core cos-data-access COS-Hardware COS-Infra
    COS-LangGraph COS-MSE COS-Network COS-SGL
    cos-signal-bridge cos-signal-explorer coinbase_websocket_BTC_pricefeed
    cos-webpage EDGAR-Forge FRED-Forge imf-forge ingest
    OrbWeaver quant-dashboard stooq-forge
    # EXCLUDED per D-12: capability-gated-agent-architecture (lowercase duplicate)
    # EXCLUDED per planner decision: cos-docs (this aggregator), COS-electrs (Rust)
)

# D-09 diagram-exempt list (referenced by content-pass plan, not by wrapper logic)
DIAGRAM_EXEMPT=( COS-Hardware COS-Network COS-Capability-Gated-Agent-Architecture )

# Module-name overrides for repos where [project].name != importable module
declare -A PACKAGE_OVERRIDES=(
    [COS-LangGraph]=langgraph_agent
    # add more after first-sweep verification
)

declare -A REPO_STATUS

preflight() { ... }   # see Pattern 1
build_smoke() { ... } # see Pattern 3
commit_scaffold() {
    local repo_path="$1"
    git -C "$repo_path" add docs/index.md docs/architecture.md \
        ${repo_type:+docs/api.md} mkdocs.yml requirements-docs.txt
    git -C "$repo_path" commit -m "docs: add cos-docs scaffold (content to follow)"
}

for repo in "${ROLLOUT_LIST[@]}"; do
    path="$WORKSPACE/$repo"
    if ! preflight "$path"; then
        REPO_STATUS["$repo"]="SKIP: $(preflight "$path" 2>&1 | tail -1)"; continue
    fi
    "$SCAFFOLD_SH" "$path" > "$LOG_DIR/$repo.scaffold.log" 2>&1 \
        || { REPO_STATUS["$repo"]="FAIL: scaffold"; continue; }
    build_smoke "$path" > "$LOG_DIR/$repo.build.log" 2>&1 \
        || { REPO_STATUS["$repo"]="FAIL: mkdocs build"; continue; }
    commit_scaffold "$path" > "$LOG_DIR/$repo.commit.log" 2>&1 \
        || { REPO_STATUS["$repo"]="FAIL: git commit"; continue; }
    REPO_STATUS["$repo"]="OK"
done

# Final summary (greppable, per CONTEXT.md "Specifics")
echo
echo "=== scaffold-all.sh summary ==="
printf "%-50s %s\n" "REPO" "STATUS"
printf "%-50s %s\n" "----" "------"
for repo in "${ROLLOUT_LIST[@]}"; do
    printf "%-50s %s\n" "$repo" "${REPO_STATUS[$repo]}"
done
echo
echo "Per-repo logs: $LOG_DIR"
```

### Example 2: Pre-Flight Output (greppable, D-03 "Specifics")

```
=== scaffold-all.sh summary ===
REPO                                               STATUS
----                                               ------
bis-forge                                          SKIP: dirty working tree
bls-forge                                          SKIP: dirty working tree
BTC-Forge                                          SKIP: dirty working tree
COS-Bitcoin-Protocol-Intelligence-Platform         OK
COS-BTC-Network-Crawler                            OK
COS-BTC-Node                                       SKIP: dirty working tree
COS-BTC-SQL-Warehouse                              SKIP: dirty working tree
COS-BTE                                            SKIP: dirty working tree
COS-CIE                                            SKIP: branch=master (D-02 expects main)
COS-Core                                           OK
COS-LangGraph                                      FAIL: mkdocs build (module mismatch)
...
```

User can `grep '^[^O].*SKIP\|FAIL'` to get an action list.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `python -m venv` | `uv venv` | uv 0.1+ (~2024) | 5-10× faster venv create + pip install; workspace-standard since `ingest` adopted `uv.lock` |
| `requirements.txt` global pinning | per-repo `requirements-docs.txt` (D-15) | Phase 1, 2026-04 | Repo independence; no shared cos-docs venv assumption |
| `mkdocs serve` for smoke testing | `mkdocs build --strict` | mkdocs 1.4+ | Catches warnings as errors; better CI fit (Phase 4) |
| LLM-assisted bulk content drafting | Hand-authoring (D-05) | CONTEXT.md 2026-04-19 | Quality > speed for solo-maintained docs |

**Deprecated/outdated:**
- `mkdocs-material==1.6.1` (CONTEXT.md original D-16 typo) → corrected to `9.7.6` in Plan 01-02
- mkdocstrings auto-loading griffe extensions → as of 1.0.x must be explicitly listed (`extensions: [griffe_pydantic]`); fix landed in Plan 01-02 commit ded6955

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Other Python repos use Pydantic v2 (not v1) | Failure Mode 4 | griffe-pydantic 1.3.1 wouldn't extract field docs; mkdocs --strict would warn but not fail. Mitigation: planner runs `grep -r 'pydantic<2' /home/btc/github/*/pyproject.toml` at plan time; near-zero matches expected. |
| A2 | mkdocstrings plugin is harmless when no `:::` directives appear in any page (TS/docs-only repos) | Failure Mode 3 | If FALSE, `mkdocs build --strict` fails for every TS/docs-only repo. Wrapper can't proceed for ~7 repos. Mitigation: smoke-test against cos-webpage during wrapper development before full sweep. |
| A3 | uv is preferable to python -m venv for the per-repo doc venv | Standard Stack | Both work; uv is faster but adds a tool dep. uv already on host. No real risk; minor speed/style choice. |
| A4 | Module-name mismatches exist beyond COS-LangGraph | Pitfall 4 | If FALSE, the PACKAGE_OVERRIDES map is unnecessary complexity. Cheap to verify at plan time (one `python -c "import X"` per Python repo). |
| A5 | Plan-checker won't gate phase completion on incremental content-authoring tasks (Option C plan structure) | Hand-Authoring Workflow | If plan-checker is strict, the phase stays "in progress" until every repo's content is filled — could be weeks of editorial work. Recommend planner explicitly note "content-pass plan tracks incrementally; phase verification happens when CONT-* requirements are met, not when every task is checked." |
| A6 | The 8 disk repos missing from CLAUDE.md project map should all be INCLUDED in rollout | Repo Inventory | CONTEXT.md D-11 said "verbatim from CLAUDE.md project map." This research recommends amending — but the user may have intentionally excluded the 8 (e.g., COS-MSE may be experimental, cos-webpage may be deprecated). Plan task: confirm with user during plan-time review before finalizing rollout list. **HIGH IMPACT — this is the single most important question for the planner to answer before coding the wrapper.** |
| A7 | "Skip dirty repos" is the right policy (vs. auto-stash, vs. fail-loud) | Pattern 1 | If user expects auto-stash, scaffolding gets blocked on 14/31 repos and the rollout grinds to a halt with no clear next action. Mitigation: SKIP with explicit reason in summary; user fixes manually then re-runs (current `scaffold.sh` already supports single-repo invocation — no `--only` flag needed). |

## Open Questions

1. **Does mkdocstrings emit a warning OR an error when the `:::` target can't be imported?** Phase 1 verified COS-Core (where the package was importable after `pip install -e .`). The wrapper assumes "warning only" → `--strict` would fail catching the case. Should be verified by the implementer with one deliberate mismatch. If it's a silent miss, wrapper needs a post-build grep on the rendered HTML to confirm the package was actually rendered (analogous to Plan 01-02's `grep 'Lowercase exchange name'` smoke).
2. **What is the actual importable module name for each Python repo (not just `[project].name`)?** Per Pitfall 4: needs a one-time verification sweep at plan time. This produces the PACKAGE_OVERRIDES map.
3. **Should COS-electrs (Rust) be included as docs-only or excluded entirely?** Recommend EXCLUDE for v1 (this research). Plan-time decision.
4. **Are the 8 disk repos missing from CLAUDE.md intentional exclusions or omissions?** Per A6 — needs user confirmation before wrapper coding.
5. **Should the wrapper auto-switch from `master` to `main` (or treat `master` as equivalent)?** D-02 says "main branch"; 4 repos are on `master` by long-standing convention. Recommend treat both as acceptable defaults; SKIP only when on a clear feature branch (`kubernetes`, `spec-decomposition-extraction`, `new-index`).

## Environment Availability

[VERIFIED: `command -v` / `--version` checks 2026-04-19]

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | wrapper script | ✓ | 5.x | — |
| Python 3.11+ | per-repo doc venv | ✓ | 3.12.3 (system) | — |
| uv | per-repo venv + pip install | ✓ | 0.10.2 | `python -m venv` + `pip install` (slower) |
| git | per-repo commit | ✓ | system | — |
| mkdocs (transitively via Phase 1's `requirements-docs.txt`) | smoke gate | ✓ on demand | per Phase 1 D-16 pins | — |
| internet | PyPI fetch during per-repo `pip install` | assumed ✓ | — | local pip cache (uv caches by default) |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None — environment is fully provisioned.

## Validation Architecture

`workflow.nyquist_validation` is `false` in `cos-docs/.planning/config.json`. **Section omitted per the conditional rule.**

(Phase 1 verified manually with E2E smoke against COS-Core — `mkdocs build --strict` exit code + grep on rendered HTML for known field-docstring substring. Phase 2 should reuse this verification approach as part of the wrapper's smoke-gate output, not a separate pytest harness.)

## Security Domain

`security_enforcement` is not set in config (defaults to enabled). However, **all relevant ASVS categories are NOT applicable to Phase 2:**

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — wrapper runs locally on maintainer's workstation, no remote auth |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a — wrapper inherits filesystem permissions of invoking user |
| V5 Input Validation | no | n/a — wrapper takes no untrusted input; rollout list is hardcoded |
| V6 Cryptography | no | n/a — no secrets, no crypto |

**Threat patterns relevant to wrapper bash:**

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Path injection via repo name (e.g., `../../etc/passwd`) | Tampering | Hardcoded ROLLOUT_LIST array — no user-supplied paths. If plan adds `--only <repo>` flag, sanitize against the array contents. |
| Accidental credential commit | Information Disclosure | Wrapper uses explicit `git add <file>` (not `git add -A`); pre-flight rejects dirty trees so unrelated WIP can't sneak in. |
| Unintended branch push | Tampering | Wrapper does NOT `git push` — all commits stay local. Maintainer manually pushes after review. **Plan task: explicitly document "wrapper does not push" in usage comment.** |

## Sources

### Primary (HIGH confidence)
- `/home/btc/github/cos-docs/scripts/scaffold.sh` — Phase 1 deliverable; full source read
- `/home/btc/github/cos-docs/.planning/phases/02-content-migration/02-CONTEXT.md` — locked decisions
- `/home/btc/github/cos-docs/.planning/phases/01-scaffold-template/01-CONTEXT.md` — Phase 1 decisions D-01..D-17
- `/home/btc/github/cos-docs/.planning/phases/01-scaffold-template/01-02-SUMMARY.md` — verified pin versions, mkdocstrings handler config, COS-Core E2E smoke results
- `/home/btc/github/cos-docs/.planning/REQUIREMENTS.md` — CONT-01..04, DIAG-02 wording (for amendment)
- `/home/btc/github/cos-docs/.planning/PROJECT.md` — stack, constraints, Key Decisions
- `/home/btc/github/cos-docs/.planning/ROADMAP.md` — Phase 2 goal + 5 success criteria
- `/home/btc/github/cos-docs/.planning/config.json` — `nyquist_validation: false`, `commit_docs: true`
- Filesystem audit `/home/btc/github/` (2026-04-19) — per-repo branch, dirty status, marker files, source-material readiness
- `/home/btc/github/CLAUDE.md` — workspace project map (cross-referenced against disk for staleness)

### Secondary (MEDIUM confidence)
- mkdocstrings python handler docs: https://mkdocstrings.github.io/python/ [CITED — referenced for D-07 per-submodule rendering options]
- mkdocs strict-build behavior: https://www.mkdocs.org/user-guide/configuration/#strict [CITED — referenced for D-04 wrapper integration]
- uv docs: https://docs.astral.sh/uv/ [ASSUMED for venv-creation behavior; uv is workspace-standard]

### Tertiary (LOW confidence)
- mkdocstrings warning-vs-error behavior on unresolvable `:::` targets [ASSUMED — Open Question 1]
- Pydantic v1 prevalence in workspace repos [ASSUMED — A1, easy to verify at plan time]

## Metadata

**Confidence breakdown:**
- Repo inventory + reconciliation: HIGH — direct filesystem audit
- Wrapper architecture: HIGH — bash patterns are stable, scaffold.sh source read in full
- Per-repo build failure modes (Pitfall 4 / module-name mismatches): MEDIUM — verified COS-LangGraph mismatch; other repos need plan-time spot checks
- mkdocstrings strict-build behavior on TS/docs-only repos: MEDIUM — assumed harmless, not verified
- Hand-authoring plan structure (Option A/B/C): MEDIUM — recommendation based on workflow ergonomics, not enforced by tooling

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (30 days; mkdocs/uv ecosystems are stable, but workspace repo inventory drifts — re-verify if plan execution slips past mid-May)
