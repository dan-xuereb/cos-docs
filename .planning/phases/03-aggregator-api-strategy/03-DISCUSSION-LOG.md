# Phase 3: Aggregator & API Strategy - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 03-aggregator-api-strategy
**Areas discussed:** API-02 strategy, Domain nav + landing page, Workspace data-flow diagram, Build robustness + strict mode

---

## API-02 Strategy

### Q: Which API-docs strategy for Phase 3?

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-rendered per-repo CI | Each repo's CI builds its own API pages; aggregator fetches + embeds | ✓ |
| Mega-venv at aggregator build | cos-docs installs all 25 packages in one venv at build time | |
| Hybrid: per-repo venvs in aggregator CI | Aggregator CI creates one venv per repo, composes HTML | |
| Defer decision — spike first | Run a Phase 3 spike benchmarking both strategies | |

**User's choice:** Pre-rendered per-repo CI
**Notes:** Dep isolation wins over mega-venv given 02-02's observed `pip install -e .` failures for COS-CIE and cos-signal-bridge.

### Q: URL layout for API pages?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-repo `/{repo}/api/` nested | API is one page within each repo's doc tree, as scaffolded today | ✓ |
| Global `/api/` namespace | All API docs aggregated under one top-level section | |
| Both | Per-repo api.md + top-level cross-repo symbol index | |

**User's choice:** Per-repo `/{repo}/api/` nested

### Q: CI scope in Phase 3?

| Option | Description | Selected |
|--------|-------------|----------|
| Build-time only; CI wiring in Phase 4 | Phase 3 proves strategy locally; CI automation deferred | ✓ |
| Full CI wiring in Phase 3 | Ship per-repo GitHub Actions workflows in Phase 3 | |

**User's choice:** Build-time only; CI wiring in Phase 4

### Q (follow-up): How does Phase 3 produce per-repo API artifacts before Phase 4 wires CI?

| Option | Description | Selected |
|--------|-------------|----------|
| Local `build-all-api.sh` script in cos-docs/scripts/ | Loops repos, isolated venv per repo, runs mkdocs build locally. Phase 4 replaces with CI matrix | ✓ |
| Per-repo `docs/api/` prebuilt and committed | Commit generated API artifacts into each repo; risk of staleness | |
| Declarative api.md stays; aggregator does JIT isolated builds | Aggregator CI creates per-repo venvs at build time | |

**User's choice:** Local build-all-api.sh script in cos-docs/scripts/
**Notes:** Resolves the tension that pre-rendered-via-CI was chosen but CI is deferred — the script is the pre-CI contract.

---

## Domain Nav + Landing Page

### Q: How should the ambiguous repos be grouped in the aggregator nav?

| Option | Description | Selected |
|--------|-------------|----------|
| Pragmatic placement | cos-data-access→Schema, cos-webpage→Presentation, COS-CGAA→Infra, COS-BTC-Node→Warehouse, qd-k8s-deploy→Infra, COS-Hardware/Network/Infra→Infra | ✓ |
| Add 9th bucket: 'Docs & Specs' | Pull doc-only/spec-only repos into their own section | |
| Let me specify placements | User types exact domain per ambiguous repo | |

**User's choice:** Pragmatic placement

### Q: Within a domain, what ordering?

| Option | Description | Selected |
|--------|-------------|----------|
| Alphabetical | Predictable; no maintenance burden | ✓ |
| Importance / pipeline order | Hand-curated per domain (e.g., SDL→SGL→CIE→bridge→explorer) | |

**User's choice:** Alphabetical

### Q: What does cos-docs/docs/index.md contain beyond the nav?

| Option | Description | Selected |
|--------|-------------|----------|
| Repo index table + quick-start + one-line domain descriptions | Scannable table; `mkdocs serve/build` instructions; minimal CLAUDE.md overlap | ✓ |
| Minimal stub | One-paragraph overview + link to architecture.md | |
| Port parent /home/btc/github/CLAUDE.md | Reuse workspace CLAUDE.md verbatim | |

**User's choice:** Repo index table + quick-start + one-line domain descriptions

### Q: What does cos-docs/docs/architecture.md contain?

| Option | Description | Selected |
|--------|-------------|----------|
| Workspace-wide data-flow diagram + narrative | DIAG-03 Mermaid centerpiece + short narrative; links to per-repo architecture.md | ✓ |
| Multiple diagrams, one per flow | Separate diagrams for real-time / ETL / agent / presentation | |

**User's choice:** Workspace-wide data-flow diagram + narrative

---

## Workspace Data-Flow Diagram (DIAG-03)

### Q: What level of detail for the Mermaid diagram?

| Option | Description | Selected |
|--------|-------------|----------|
| Domain-level with key arrows | ~8 nodes + 5–6 critical arrows; fits single screen | ✓ |
| Repo-level | All 25 repos as nodes + every observed edge | |
| Tabbed by flow | One diagram per flow via pymdownx.tabbed | |

**User's choice:** Domain-level with key arrows

### Q: Hand-authored vs generated?

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-authored, reviewed | Claude drafts Mermaid source; user reviews; no generator | ✓ |
| Generated from a manifest | YAML manifest → Mermaid source script | |

**User's choice:** Hand-authored, reviewed

### Q: Should the diagram be mirrored anywhere else?

| Option | Description | Selected |
|--------|-------------|----------|
| Aggregator-only | Lives only in cos-docs/docs/architecture.md | ✓ |
| Also embedded in parent CLAUDE.md | Copy Mermaid source into workspace CLAUDE.md | |

**User's choice:** Aggregator-only

---

## Build Robustness + Strict Mode

### Q: How should Phase 3 handle the 19 SKIP + 2 FAIL repos from 02-02?

| Option | Description | Selected |
|--------|-------------|----------|
| Block Phase 3 on 02-03 + user triage | Hard-dep on plan 02-03 completion + user triaging 17 dirty-tree + 4 non-main-branch repos | ✓ |
| Defensive aggregator with explicit skip list | Aggregator !includes only buildable repos; static EXCLUDE list with reasons | |
| Run per-repo content + triage inside Phase 3 | Fold 02-03 and triage into Phase 3 as prerequisite plan | |

**User's choice:** Block Phase 3 on 02-03 completion + user triage

### Q: mkdocs build --strict policy at the aggregator?

| Option | Description | Selected |
|--------|-------------|----------|
| --strict required; CI fails on any warning | Zero tolerance; matches AGGR-04 verbatim | ✓ |
| Non-strict local, --strict in CI only | Developer-ergonomic local; CI gate enforces | |
| Warning-gate (regression only) | Baseline current warnings; fail on new only | |

**User's choice:** --strict required; CI fails on any warning

### Q: What belongs in Phase 3's plan structure?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 plans: aggregator+nav → API build script → diagram + landing | Mirrors three decision clusters; matches ROADMAP's "3 plans" count | ✓ |
| 4 plans: add 'verify all 25 repos build' plan first | Gates on clean-rollout verification | |
| Claude plans structure during plan-phase | Let gsd-planner decide boundaries | |

**User's choice:** 3 plans (aggregator+nav → API build script + artifacts → workspace diagram + landing)

---

## Claude's Discretion

- Specific Mermaid styling (LR vs TD orientation, colours, legend)
- Choice between `mkdocs build` or direct `mkdocstrings` invocation inside per-repo venvs in `build-all-api.sh`
- Repo index table layout in `index.md` (columns, grouping)
- Handling of docs-only repos with no Python API surface (omit `api.md` per scaffold fix 371b545)

## Deferred Ideas

- Per-repo GitHub Actions CI for API rendering (→ Phase 4 / v2 backlog)
- Cross-repo symbol index / global `/api/` namespace
- Artifact cache / artifact registry for pre-rendered API bundles (→ Phase 4)
- Manifest-driven diagram generator
- Warning-baseline regression gate
- Theme / branding customization (Material defaults for now)
- Versioned docs (mike)
