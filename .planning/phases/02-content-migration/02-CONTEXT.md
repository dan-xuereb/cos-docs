# Phase 2: Content Migration - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply the Phase 1 `scaffold.sh` tool to every in-scope sibling repo in `/home/btc/github/`, then hand-author the per-repo `docs/index.md`, `docs/architecture.md`, and (for Python repos) `docs/api.md` content sourced from each repo's existing `README.md` + `CLAUDE.md`. Each scaffolded repo previews locally with `mkdocs serve`; each is committed in-place on its own `main` branch.

Phase 2 produces the **content** that Phase 3's aggregator will compose. It does NOT touch the aggregator `mkdocs.yml` (Phase 3) and does NOT containerize/deploy (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Rollout Mechanics
- **D-01:** Add a thin wrapper `cos-docs/scripts/scaffold-all.sh` that iterates a hardcoded list of sibling repo paths and shells out to Phase 1's `scaffold.sh` per repo. Phase 1 D-04 stands — `scaffold.sh` remains single-repo; the batch list lives in the wrapper, not in `scaffold.sh`.
- **D-02:** Per-repo commit strategy: **one commit per sibling repo**, directly on that repo's `main` branch. Solo maintainer, internal docs, no PR overhead. Commit message convention: `docs: add cos-docs scaffold + initial content`. Each sibling repo's git history records the scaffold separately from cos-docs.
- **D-03:** Failure handling: **continue on failure, summarize at end.** The wrapper logs per-repo failures (scaffold errors, build errors) and prints a final summary listing failed repos. No auto-rollback; the user fixes failures by hand and re-runs against the targeted repo (or via `--force`).
- **D-04:** Per-repo smoke test: the wrapper runs `mkdocs build --strict` inside each repo (after `pip install -r requirements-docs.txt` in a per-repo venv) before moving on. This catches broken `!include` paths, Mermaid syntax errors, and missing API targets at Phase 2 time — not Phase 3 aggregation time. Aligns with Phase 2 success criterion #5.

### Content Sourcing
- **D-05:** **Hand-author per repo.** No LLM-assisted bulk drafting. The maintainer reads each repo's `README.md` + `CLAUDE.md` and writes the three docs files directly. Phase 2 is a sustained editorial effort, not a script-driven sweep — `scaffold-all.sh` handles the scaffold/commit/build mechanics; humans write the prose.
- **D-06:** `docs/index.md` content target (matches CONT-02 literally): **purpose + language/runtime + entry points + key commands.** Pull purpose from the README intro; lang/runtime from `pyproject.toml` / `package.json`; entry points from CLAUDE.md or the repo's `__main__.py` / `main.py` / `cli`; key commands from the README install/run sections.
- **D-07:** `docs/api.md` content (Python repos only — Phase 1 D-11): keep the auto-generated `::: <package_name>` block from Phase 1 D-12, then add a **hand-curated list of important submodules** rendered explicitly (e.g. `::: cos_core.models.market`, `::: cos_core.adapters.btc_forge`). Submodule list is per-repo, drawn from the module breakdown in each repo's CLAUDE.md.

### Architecture Diagrams (DIAG-02)
- **D-08:** **Skip diagrams for trivial / docs-only repos.** This is an explicit deviation from DIAG-02 ("at least one Mermaid diagram per repo"). The exempt list is hardcoded in `scaffold-all.sh` for visibility (see D-09). DIAG-02 needs amendment in REQUIREMENTS.md to read "per non-exempt repo" — flag this in the plan as a requirements update.
- **D-09:** Diagram-exempt repos (initial list, may grow during Phase 2 authoring):
  - `COS-Hardware` — server hardware specs / inventory; no software architecture
  - `COS-Network` — physical/VLAN/routing/firewall configs; no software architecture
  - `COS-Capability-Gated-Agent-Architecture` — formal spec, not running software
  - Any other repo flagged at authoring time goes into the exempt list before commit
- **D-10:** Diagram level for non-exempt repos: **author-chosen mix** — module/component graph for libraries (e.g. `COS-Core`, `COS-SGL`), data-flow diagram for pipeline repos (forges, `COS-BTC-SQL-Warehouse`), or both for service repos (`COS-LangGraph`, `COS-Bitcoin-Protocol-Intelligence-Platform`). Match the level of detail already in `/home/btc/github/CLAUDE.md`.

### Repo Coverage & Scope
- **D-11:** Authoritative repo list = the **project map table in `/home/btc/github/CLAUDE.md`**, taken verbatim (~25 rows). Each row maps to one wrapper iteration. No additional curation.
- **D-12:** Duplicate handling: keep `COS-Capability-Gated-Agent-Architecture` (PascalCase, matches workspace convention); **explicitly exclude the lowercase `capability-gated-agent-architecture` duplicate** from the rollout list. Document the exclusion in `scaffold-all.sh` so the next maintainer sees it.
- **D-13:** Repo-type behavior is inherited from Phase 1: `pyproject.toml` → python (gets `docs/api.md`), `package.json` → ts (no api.md), neither → docs-only (no api.md). Mixed repos = python primary (Phase 1 D-10).

### Claude's Discretion
- Exact bash style of `scaffold-all.sh` (associative arrays vs parallel arrays for the exempt list; per-repo venv via `python -m venv` vs `uv venv`) — implementer's choice.
- Build-test parallelism (sequential vs xargs `-P N`) — sequential is simpler; planner may parallelize if the sweep is too slow.
- Whether `scaffold-all.sh` accepts `--only <repo>` for re-running a single failed repo — planner can add if useful, not required.
- Final summary format (tabular vs JSON vs both) — implementer's choice.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context (cos-docs)
- `.planning/PROJECT.md` — Stack, constraints, Key Decisions table; in particular the "All ~25 repos scaffolded in v1" and "Full content pass per repo" decisions.
- `.planning/REQUIREMENTS.md` — CONT-01..04, DIAG-02 are the locked Phase 2 acceptance criteria. **DIAG-02 needs amendment per D-08 (exempt-list deviation).**
- `.planning/ROADMAP.md` §"Phase 2: Content Migration" — Goal + 5 success criteria
- `.planning/phases/01-scaffold-template/01-CONTEXT.md` — Phase 1 decisions D-01..D-17 (scaffold tool form, file ownership, repo-type detection, version pins). All carry forward.
- `.planning/phases/01-scaffold-template/01-VERIFICATION.md` — confirms scaffold.sh works against COS-Core; that's the smoke-test baseline for Phase 2's wrapper.

### Workspace context
- `/home/btc/github/CLAUDE.md` §"Project Map" — **authoritative repo list for D-11.** Also workspace tech-stack / domain groupings used to inform per-repo content authoring.
- Per-repo `README.md` + `CLAUDE.md` (where present) — **the source material for D-05 hand-authoring.** Every in-scope repo has a README; many have a CLAUDE.md.

### Spike findings (validated patterns to follow)
- Spike 001 `monorepo-plugin-aggregation` — `!include` directive in mkdocs.yml (already wired by Phase 1; Phase 2 doesn't touch this)
- Spike 002 `pydantic-mkdocstrings` — Pydantic v2 trailing-string field docstrings render natively; relevant when curating the D-07 submodule list for `COS-Core` and Pydantic-heavy repos
- Spike 003 `mermaid-architecture-diagrams` — `pymdownx.superfences` Mermaid `custom_fence` (already wired by Phase 1); Phase 2 uses this when authoring D-10 diagrams

### External docs (planner reads at plan time)
- mkdocstrings python handler: https://mkdocstrings.github.io/python/ — for D-07 per-submodule rendering options
- mkdocs strict-build behavior: https://www.mkdocs.org/user-guide/configuration/#strict — for D-04 wrapper integration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cos-docs/scripts/scaffold.sh` — Phase 1 deliverable. The wrapper invokes this per-repo; D-04's `--force` flag exists if the wrapper needs to re-stamp scaffold-owned files (`mkdocs.yml`, `requirements-docs.txt`).
- Phase 1's atomic-write + diff-on-overwrite pattern (D-06 in Phase 1) — wrapper inherits this safety automatically; no extra work needed.
- Existing `README.md` + `CLAUDE.md` in every sibling repo — the source material for D-05.

### Established Patterns (workspace-level)
- Workspace bash convention: `#!/usr/bin/env bash`, `set -euo pipefail`, top-of-file usage comment. `scaffold-all.sh` matches Phase 1's `scaffold.sh` style.
- Per-repo `pyproject.toml` `[project].name` is reliably populated across the Python repos (Phase 1 D-13 verified) — D-07's submodule curation can rely on this for default package roots.
- COS-Core's Pydantic v2 trailing-string docstring convention is workspace-wide for COS-prefixed Python repos — `griffe-pydantic` rendering will work uniformly without per-repo config tweaks.

### Integration Points
- Each repo's resulting `mkdocs.yml` becomes a Phase 3 `!include` target. The `nav:` structure that Phase 1's template establishes is what Phase 3 aggregator surfaces — **do not change per-repo nav layout in Phase 2.**
- Each repo's `requirements-docs.txt` (Phase 1 D-15) is what Phase 4 CI will `pip install -r` during the aggregator build. **Do not delete or rename it during content authoring.**
- The diagram-exempt list (D-09) becomes a contract for Phase 3 — exempt repos' `architecture.md` will be prose-only, no Mermaid; Phase 3 should not assume every repo has a diagram.

</code_context>

<specifics>
## Specific Ideas

- The wrapper's failure summary should be greppable (one-line-per-repo, status code, short reason) so the user can quickly target the next `scaffold.sh /path/to/failing-repo` invocation.
- Per-repo authoring sessions can run independently of the wrapper — D-05 (hand-author) means scaffold-all.sh's job ends at scaffold + build-test; humans pick up from there per repo, in any order.
- Reference target for D-07 quality bar: `COS-Core` (already proven by Phase 1 verification — Pydantic field docstrings render). Use it as the visual benchmark for "what good api.md looks like" when curating other repos.
- Domain grouping from `/home/btc/github/CLAUDE.md` (Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure) is **not** part of Phase 2 — that's AGGR-02 (Phase 3 aggregator nav). Phase 2 produces flat per-repo docs; grouping happens in Phase 3.

</specifics>

<deferred>
## Deferred Ideas

- LLM-assisted bulk drafting of per-repo content — explicitly rejected for Phase 2 (D-05). Could be revisited if the hand-authoring effort proves unsustainable mid-rollout, but not in scope now.
- A `--only <repo>` flag for `scaffold-all.sh` (re-run a single failed repo) — planner discretion.
- Parallel execution of the per-repo build-test loop — planner discretion; sequential is the default.
- Per-page mkdocstrings options heavier than D-07's curated submodule list — left to per-repo authoring judgment, not a Phase 2 contract.
- Filling diagrams for the D-09 exempt repos — not in v1; if it becomes valuable, future requirement.
- Resolving the `capability-gated-agent-architecture` lowercase duplicate at the filesystem level (deleting/merging it) — out of scope for Phase 2; just excluded from rollout (D-12).

</deferred>

---

*Phase: 02-content-migration*
*Context gathered: 2026-04-19*
