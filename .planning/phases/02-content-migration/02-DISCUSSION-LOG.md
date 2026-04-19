# Phase 2: Content Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 02-content-migration
**Areas discussed:** Rollout mechanics, Content sourcing approach, Architecture diagrams (DIAG-02), Repo coverage & scope

---

## Rollout Mechanics

### Q: How should scaffold.sh be applied across all ~25 repos?

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrapper loop | New `cos-docs/scripts/scaffold-all.sh` iterates a hardcoded list and shells out per repo. Keeps Phase 1 D-04. | ✓ |
| Add --all flag to scaffold.sh | Extend scaffold.sh with batch mode. Reverses Phase 1 D-04. | |
| Manual one-by-one | Phase 2 plan walks each repo by hand. | |

### Q: Per-repo commit/branch strategy in each sibling repo?

| Option | Description | Selected |
|--------|-------------|----------|
| One commit per repo on main | Single `docs:` commit per sibling, directly on main. Solo maintainer, internal docs. | ✓ |
| Branch + PR per repo | docs/cos-docs-init branch + PR per sibling. | |
| Multi-commit per repo | Two commits: scaffold then content. | |

### Q: How should rollout failures be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Continue on failure, summarize at end | Wrapper logs failures, prints final summary; user fixes by hand. | ✓ |
| Fail fast, halt on first error | Stop at first failure; user fixes and re-runs. | |
| Continue, but auto-rollback failed repos | git restore in failing repo to undo partial scaffold. | |

### Q: Should the rollout produce a smoke-test signal per repo (`mkdocs build --strict`)?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, run per repo as part of wrapper | `pip install -r requirements-docs.txt && mkdocs build --strict` per repo in tmp venv. | ✓ |
| Skip; rely on aggregator build in Phase 3 | Phase 2 only writes content; Phase 3 catches issues. | |
| Sample subset only | Build-test 3-4 representative repos. | |

---

## Content Sourcing Approach

### Q: How should index/architecture/api content be derived from README + CLAUDE.md?

| Option | Description | Selected |
|--------|-------------|----------|
| LLM-assisted per-repo drafting | LLM reads README + CLAUDE.md, drafts the three docs; human reviews. (Originally recommended.) | |
| Mechanical section extraction | Deterministic script splits by heading. Brittle across varied READMEs. | |
| Hand-author per repo | Open each repo, write the three docs from scratch using README/CLAUDE.md as reference. | ✓ |
| Stub now, fill later | Minimal stubs, defer real migration. | |

**Notes:** This is a significant choice — Phase 2 becomes a sustained editorial effort, not a script-driven sweep. The wrapper script handles scaffold + commit + build mechanics; humans write the prose per repo.

### Q: What should index.md actually contain per repo?

| Option | Description | Selected |
|--------|-------------|----------|
| Purpose + lang/runtime + entry points + key commands | Matches CONT-02 literally. | ✓ |
| Same as above + quickstart code block | Adds a runnable example. | |
| Purpose only, terse | One paragraph; defer details. | |

### Q: How should api.md content be authored beyond the auto ::: <package_name> block?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-block + curated module list | Keep Phase 1's block, add hand-picked submodules per repo from CLAUDE.md. | ✓ |
| Auto-block only | Trust mkdocstrings + show_submodules to surface everything. | |
| Per-repo handwritten api.md | Fully custom api.md per repo. | |

---

## Architecture Diagrams (DIAG-02)

### Q: How should each repo's Mermaid architecture diagram be sourced?

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-draft per repo, reuse CLAUDE.md if present | Port from CLAUDE.md where available; hand-draft the rest. (Originally recommended.) | |
| Boilerplate stub + TODO marker | Minimal placeholder; flag for follow-up. | |
| Skip diagrams for trivial/docs-only repos | Only meaningful service/library repos get diagrams; explicit exempt list. | ✓ |

**Notes:** Selection is an explicit deviation from DIAG-02 ("at least one Mermaid diagram per repo"). DIAG-02 needs amendment in REQUIREMENTS.md to read "per non-exempt repo" — flagged in CONTEXT.md D-08 for the planner to address.

### Q: What level of diagram should the per-repo architecture.md aim for?

| Option | Description | Selected |
|--------|-------------|----------|
| Internal module/component graph | Boxes-and-arrows of major modules within the repo. | |
| Data flow diagram | Inputs/outputs across external interfaces. | |
| Both, where the repo warrants it | Author chooses per repo (module graph for libraries, data flow for pipelines, both for services). | ✓ |

---

## Repo Coverage & Scope

### Q: Which repos are in Phase 2 scope?

| Option | Description | Selected |
|--------|-------------|----------|
| All ~25 listed in CLAUDE.md project map | Take the project map verbatim; includes docs-only and spec repos. | ✓ |
| Python + TS only | Skip docs-only/spec/config. Reduces to ~20. | |
| Custom curated list | Maintainer hand-picks an explicit include list. | |

### Q: How should diagram-exempt repos be specified?

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded list in scaffold-all.sh | EXEMPT_DIAGRAM=(...) array in the wrapper; documented in CONTEXT.md. | ✓ |
| Per-repo flag file | Drop a marker (e.g. `.docs-no-diagram`) in exempt repos. | |
| Decide per repo at authoring time | No formal list; author judgment. | |

### Q: How should duplicates / sub-spec dirs (e.g. PascalCase vs lowercase capability-gated-agent-architecture) be handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Pick one canonical, exclude duplicate | Keep PascalCase; exclude lowercase from rollout; document exclusion. | ✓ |
| Scaffold both | Treat as independent repos. | |
| Investigate and resolve before Phase 2 starts | Pre-phase task to confirm with maintainer. | |

---

## Claude's Discretion

- Bash style of `scaffold-all.sh` (associative vs parallel arrays for exempt list)
- Per-repo venv mechanism (`python -m venv` vs `uv venv`)
- Build-test parallelism (sequential vs xargs `-P N`)
- Whether to add `--only <repo>` flag for re-running single failed repos
- Final summary format (tabular vs JSON)

## Deferred Ideas

- LLM-assisted bulk drafting (explicitly rejected for Phase 2)
- `--only <repo>` flag (planner discretion)
- Parallel build-test execution (planner discretion)
- Per-page mkdocstrings options beyond curated submodule list
- Filling diagrams for D-09 exempt repos
- Resolving the `capability-gated-agent-architecture` lowercase duplicate at the filesystem level
