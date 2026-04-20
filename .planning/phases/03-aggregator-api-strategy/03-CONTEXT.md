# Phase 3: Aggregator & API Strategy - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Compose all ~25 sibling repos' per-repo `docs/` trees into a single buildable `cos-docs/` site — domain-grouped nav via `mkdocs-monorepo-plugin` + `!include`, a workspace-wide Mermaid data-flow diagram, a top-level landing page, and a decided-and-recorded API-docs strategy that produces populated API pages for every Python repo. Strict-mode aggregator build is required.

**In scope:** aggregator `mkdocs.yml`, top-level `docs/index.md` + `docs/architecture.md`, per-repo API artifact generation, strict-build enforcement.
**Out of scope:** Docker/K8s deploy (Phase 4), GitHub Actions / CI wiring (Phase 4), per-repo content authoring (Phase 2 plan 02-03), per-repo triage of the 19 SKIP + 2 FAIL repos from 02-02 (user-owned, prerequisite).

</domain>

<decisions>
## Implementation Decisions

### API-02: API-docs strategy

- **D-01:** **Pre-rendered per-repo API artifacts** is the chosen strategy (over mega-venv or hybrid aggregator-side sparse installs). Rationale: 02-02 empirically showed `pip install -e .` fails for workspace-dep packages (COS-CIE, cos-signal-bridge needed `--no-deps`); mega-venv will not survive 25 repos' transitive-dep collisions.
- **D-02:** API pages live at **per-repo `/{repo}/api/`** in the built site (e.g., `/cos-core/api/`, `/cos-sgl/api/`). No global `/api/` namespace, no cross-repo symbol index.
- **D-03:** Phase 3 ships a **local build script** — `cos-docs/scripts/build-all-api.sh` — that loops each Python repo, creates an isolated venv, runs per-repo `mkdocs build` (or `mkdocstrings` directly) to produce static API HTML/Markdown that the aggregator consumes. Phase 4 later replaces the loop with a GitHub Actions matrix.
- **D-04:** **CI wiring is deferred to Phase 4.** Phase 3 proves the strategy end-to-end locally and records the decision as a Key Decision in `PROJECT.md` (satisfies API-02). The `build-all-api.sh` script is the contract Phase 4's CI will implement.
- **D-05:** Per-repo `api.md` files keep their current declarative `mkdocstrings` form (from Phase 1 scaffold). The build script calls `mkdocs build` inside each repo's isolated venv; aggregator `!include` picks up the per-repo `mkdocs.yml` as usual.
- **D-06:** Workspace-dep install fallback (`pip install --no-deps -e .`) observed in 02-02 applies here too — the build script must handle this failure mode (documented; not a scaffold.sh regression).

### Domain nav grouping + ordering

- **D-07:** Aggregator nav uses the 8 domain headers locked by AGGR-02: **Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure.** No 9th bucket.
- **D-08:** Ambiguous-repo placement (pragmatic):
  - `cos-data-access` → **Schema** (typed query layer over COS catalog)
  - `cos-webpage` → **Presentation**
  - `COS-Capability-Gated-Agent-Architecture` → **Infrastructure** (spec/arch doc, not a runtime service)
  - `COS-BTC-Node` → **Warehouse** (upstream of the ETL)
  - `quant-dashboard-k8s-deployment` → **Infrastructure**
  - `COS-Hardware`, `COS-Network`, `COS-Infra` → **Infrastructure**
- **D-09:** Within each domain: **alphabetical ordering.** No hand-curated pipeline-order exception.
- **D-10:** Excluded repos (already locked): **`COS-electrs`** (Rust / Cargo only — doesn't fit the MkDocs pipeline) and the lowercase duplicate **`capability-gated-agent-architecture`** (PascalCase version is canonical).

### Top-level landing + architecture pages

- **D-11:** `cos-docs/docs/index.md` contains: **(a)** a scannable repo index table (name, language/runtime, one-line purpose, link), **(b)** `mkdocs serve` / `mkdocs build` quick-start, **(c)** a short one-line description per domain. Minimal overlap with `/home/btc/github/CLAUDE.md`; no verbatim port.
- **D-12:** `cos-docs/docs/architecture.md` is built around the DIAG-03 workspace Mermaid diagram + narrative explaining the real-time, batch, agent, and presentation flows. Links out to per-repo `architecture.md` files for depth.

### Workspace data-flow diagram (DIAG-03)

- **D-13:** **Domain-level granularity** — the diagram has ~8 domain nodes plus the 5–6 critical data arrows (Coinbase→pricefeed→dashboard; forges→NFS→downstream; BTC-Core→warehouse; SDL↔SGL↔BTE feedback loop; agent→tools). Must fit on a single screen.
- **D-14:** **Hand-authored** Mermaid source, reviewed by user during plan execution. No generator / manifest-to-Mermaid tooling.
- **D-15:** Diagram lives **only in the aggregator** (`cos-docs/docs/architecture.md`). Not mirrored into parent `/home/btc/github/CLAUDE.md`. Per-repo `architecture.md` files keep their repo-local diagrams.

### Build robustness + strict mode

- **D-16:** **Phase 3 hard-depends on** (a) plan 02-03 (per-repo content authoring) completing, and (b) user triage of the 17 dirty-tree + 4 non-main-branch repos from 02-02 so `scaffold.sh` can re-run cleanly on them. Aggregator expects a clean 25-repo set. The RESEARCH + PLAN steps must check this state before execution.
- **D-17:** Aggregator uses **`mkdocs build --strict`** (zero tolerance for broken `!include` or missing-anchor warnings) — both locally and in CI. Matches AGGR-04 verbatim. No warning-gate / baseline-regression model.
- **D-18:** No per-repo EXCLUDE list at the aggregator level. Every repo in `scaffold-all.sh`'s `ROLLOUT_LIST` (minus the two already-locked exclusions from D-10) must be `!include`-able at strict-build time. If a repo cannot be made strict-clean, it blocks Phase 3 rather than being skipped.

### Phase structure

- **D-19:** Phase 3 ships as **3 plans**, mirroring the three primary decision clusters and matching ROADMAP's "3 plans" count:
  1. **03-01** — Aggregator `mkdocs.yml` with `mkdocs-monorepo-plugin` + `!include` entries for all 25 repos + domain-grouped nav + strict-build passing (AGGR-01, AGGR-02, AGGR-04, AGGR-05)
  2. **03-02** — API build script (`build-all-api.sh`) + per-repo isolated-venv loop + every Python repo has populated API pages in the aggregator build; PROJECT.md Key Decision recorded (API-02, API-03)
  3. **03-03** — Workspace-wide Mermaid data-flow diagram + top-level `index.md` (repo index table + quick-start) + `architecture.md` narrative (AGGR-03, DIAG-03)

### Claude's Discretion

- Specific Mermaid styling (LR vs TD orientation, colours, legend) — Claude chooses during execution; user reviews.
- Choice between `mkdocs build` or direct `mkdocstrings` invocation inside the per-repo venvs for `build-all-api.sh` — whichever is simpler/more reliable.
- Repo index table layout in `index.md` (columns, grouping) — Claude drafts; user reviews.
- Handling of repos that legitimately have no Python API surface (docs-only: COS-Hardware, COS-Network, COS-Infra, COS-CGAA, qd-k8s-deploy) — omit their `api.md` path per the Phase 1 scaffold fix (commit 371b545).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level contracts
- `.planning/PROJECT.md` — project vision, constraints, the "Defer API-docs strategy" entry in Key Decisions that this phase resolves
- `.planning/REQUIREMENTS.md` — v1 requirements AGGR-01..05, DIAG-03, API-02, API-03 (all 8 locked to Phase 3)
- `.planning/ROADMAP.md` §"Phase 3" — goal, success criteria, phase-count commitment

### Phase 2 artifacts (the aggregator consumes what Phase 2 produced)
- `.planning/phases/02-content-migration/02-ROLLOUT-STATUS.md` — 9 OK / 2 FAIL / 19 SKIP inventory; triage debt that blocks Phase 3 per D-16
- `.planning/phases/02-content-migration/02-02-SUMMARY.md` — PACKAGE_OVERRIDES backport, workspace-dep install failure mode observed
- `.planning/phases/02-content-migration/02-03-PLAN.md` — per-repo content authoring (prerequisite per D-16)
- `.planning/phases/02-content-migration/02-CONTEXT.md` — Phase 2 decisions that carry forward

### Phase 1 artifacts (scaffold contract)
- `.planning/phases/01-scaffold-template/01-02-SUMMARY.md` — mkdocstrings + griffe-pydantic handler config; pinned requirements-docs.txt
- `scripts/scaffold.sh` (cos-docs) — per-repo scaffold emitter; `emit_mkdocs_yml`, `emit_api_md`, conditional `- API: api.md` nav
- `scripts/scaffold-all.sh` (cos-docs) — ROLLOUT_LIST, EXCLUDE_LIST, PACKAGE_OVERRIDES

### Spike findings (validated technical approach)
- Spike 001 `monorepo-plugin-aggregation` — `mkdocs-monorepo-plugin` + `!include` (NOT `!import` — wrong directive fails silently)
- Spike 002 `pydantic-mkdocstrings` — `mkdocstrings[python]` + `griffe-pydantic` renders Pydantic v2 field docs natively
- Spike 003 `mermaid-architecture-diagrams` — `pymdownx.superfences` + Material's bundled `mermaid.min.js` (no extra plugin)

### Upstream workspace
- `/home/btc/github/CLAUDE.md` §"Project Map" — canonical 26-repo inventory + domain assignments (reconciled 83683eb)

### External / upstream tooling docs
- `mkdocs-monorepo-plugin` README — `!include` directive, limitations
- `mkdocstrings[python]` + `griffe-pydantic` handler docs — config knobs, `show_submodules`, `extensions: [griffe_pydantic]`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`scripts/scaffold.sh`** (cos-docs) — produces per-repo `docs/index.md`, `docs/architecture.md`, `docs/api.md`, `mkdocs.yml`, `requirements-docs.txt`; idempotent; `--force` + `--package` flags; diff-on-overwrite. Phase 3 does NOT modify it.
- **`scripts/scaffold-all.sh`** (cos-docs) — 30-entry `ROLLOUT_LIST`, `EXCLUDE_LIST`, empirical `PACKAGE_OVERRIDES` map. The list Phase 3 builds against (minus locked exclusions) is exactly `ROLLOUT_LIST` − `EXCLUDE_LIST`.
- **Per-repo `mkdocs.yml`** — 9 OK repos already have a working site; `!include ../<repo>/mkdocs.yml` is the aggregator composition primitive.
- **Per-repo `requirements-docs.txt`** — pinned MkDocs Material + plugins; aggregator inherits compatible pins.
- **Per-repo `docs/api.md`** — declarative `mkdocstrings` page with `extensions: [griffe_pydantic]` + `show_submodules: true` (documented in 01-02-SUMMARY).

### Established patterns

- **Atomic file writes** (`tmp → rename`) — reuse in any Phase 3 scripts that mutate state.
- **`mkdocs build --strict`** — already the E2E smoke contract from Phase 1 (01-02-SUMMARY). Phase 3 promotes it to CI-gate status.
- **Per-repo isolated venv** — 02-02 proved it's needed (`pip install --no-deps -e .` fallback for workspace-dep repos); `build-all-api.sh` will formalize this.
- **Heredoc emitters with distinct terminators** — the Phase 1 convention for scaffold script heredocs; reuse for any generators in Phase 3 plans.

### Integration points

- `cos-docs/mkdocs.yml` — does not yet exist; Phase 3 creates it. Must pin `mkdocs-monorepo-plugin` version.
- `cos-docs/docs/` — does not yet exist; Phase 3 creates `index.md` + `architecture.md`.
- `cos-docs/requirements-docs.txt` — aggregator-level pinned deps; superset of per-repo requirements.
- `cos-docs/scripts/build-all-api.sh` — new script per D-03.
- Sibling repo directories `/home/btc/github/{repo}/` — read-only inputs via `!include ../{repo}/mkdocs.yml`.

</code_context>

<specifics>
## Specific Ideas

- The ROADMAP's AGGR-04 success criterion ("zero 'reference not found' warnings and zero broken `!include` errors") is the exact strict-mode contract locked in D-17 — not paraphrased, matched verbatim.
- The Key Decision text for PROJECT.md (D-04) must explicitly name the alternative rejected (mega-venv) and cite the 02-02 evidence (`--no-deps` fallback) — so the decision is auditable.
- The `build-all-api.sh` script (D-03) is designed to be CI-drop-in: Phase 4's GitHub Actions will wrap its loop body in a matrix, not replace it.

</specifics>

<deferred>
## Deferred Ideas

- **Per-repo GitHub Actions CI** for API rendering — belongs to Phase 4 and v2 Quality backlog (`Per-Repo CI` section in REQUIREMENTS.md).
- **Cross-repo symbol index / global `/api/`** — rejected for Phase 3 (D-02) but potentially valuable later; backlog candidate.
- **Artifact cache / artifact registry** for pre-rendered per-repo API bundles — only needed once CI runs; Phase 4 decision.
- **Manifest-driven diagram generator** — rejected for Phase 3 (D-14); revisit if the workspace diagram grows beyond hand-maintenance.
- **Warning-baseline regression gate** — rejected for Phase 3 (D-17); only relevant if `--strict` becomes untenable.
- **Theme / branding customization** (colours, logo, dark-mode default) — not surfaced in discussion; inherit Material defaults; backlog.
- **Versioned docs (mike)** — not requested; backlog.

</deferred>

---
*Phase: 03-aggregator-api-strategy*
*Context gathered: 2026-04-19*
