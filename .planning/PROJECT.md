# cos-docs — Xuer Capital Workspace Documentation Aggregator

## What This Is

A MkDocs Material site that aggregates documentation from ~25 sibling repos in `/home/btc/github/` into a single browsable workspace knowledge base. Each repo owns its own `docs/` tree; this aggregator pulls them together via `mkdocs-monorepo-plugin` and deploys as a containerized site to the Talos K8s cluster at `10.70.0.102` on NodePort 30081. Primary reader is the maintainer (solo) — the goal is fast cross-repo navigation, not external polish.

## Core Value

A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. -->

- [ ] Per-repo scaffold (`scaffold.sh`) drops `docs/index.md`, `docs/architecture.md`, `docs/api.md`, `mkdocs.yml` into a target repo
- [ ] All ~25 sibling repos in `/home/btc/github/` get scaffolded and content-migrated from existing `README.md` + `CLAUDE.md`
- [ ] Aggregator `mkdocs.yml` uses `!include ../<repo>/mkdocs.yml` (mkdocs-monorepo-plugin) to compose all 25 repos, grouped by domain (Forges, Signal Stack, Agent, Presentation, Warehouse, Network)
- [ ] Pydantic v2 schemas (in COS-Core and others) render as API docs via `mkdocstrings[python]` + `griffe-pydantic`
- [ ] Per-repo Mermaid architecture diagrams render via `pymdownx.superfences` + Material's bundled `mermaid.min.js`
- [ ] Top-level workspace architecture diagram renders in the aggregator (data flow across all domains)
- [ ] Multi-stage Dockerfile builds the static site; Kustomize bundle deploys to Talos K8s on NodePort 30081
- [ ] GitHub Actions on `cos-docs/`: nightly rebuild + on-push + `workflow_dispatch`
- [ ] API docs strategy decided before deploy (mega-venv vs pre-rendered per-repo) — open design call from spike findings

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Versioned docs (mkdocs `mike`) — single "latest" view is enough for solo use; versioning adds rebuild complexity without payoff
- Auth on the K8s site — internal-only network, no login wall needed
- External / public hosting polish (SEO, marketing-grade navigation) — audience is the maintainer

## Context

- **Spike validated, 2026-04-18**: 4 spikes (`monorepo-plugin-aggregation`, `pydantic-mkdocstrings`, `mermaid-architecture-diagrams`, `talos-nginx-deploy`) all returned ✓ VALIDATED. Findings packaged in spike READMEs and (pending) a project skill.
- **Workspace layout**: `/home/btc/github/` contains ~25 independent git repos (one `.git/` per subdir, no monorepo tooling). Repo inventory and architecture map live in `/home/btc/github/CLAUDE.md`.
- **Domain groupings** (from CLAUDE.md): Data Ingestion / Forges, Real-Time Market Data, On-Chain Analytics, AI Agent, Network Intelligence, Presentation, Backtesting, Schema (COS-Core).
- **Existing content**: every repo already has `README.md`; many have `CLAUDE.md`. These are the source for the v1 content migration.
- **Deploy precedent**: `quant-dashboard` already runs on the same Talos cluster (NodePort 30080); spike 004 used the same Dockerfile + Kustomize pattern. NodePort 30081 chosen to sit next to it.
- **Private container registry**: `10.70.0.30:5000` (used by all other workspace deployments).

## Constraints

- **Tech stack**: MkDocs Material (currently `v1.6.1`) + `mkdocs-monorepo-plugin` + `mkdocstrings[python]` + `griffe-pydantic` + `pymdownx.superfences`. Pin versions explicitly — Material 2.0 is announced and will break all plugins with no migration path.
- **Syntax**: `mkdocs-monorepo-plugin` uses `!include` (NOT `!import`); the wrong directive fails silently with generic "reference not found" warnings. Boilerplate this into every `mkdocs.yml` template.
- **Python**: 3.11+ (matches workspace baseline; required for griffe-pydantic on modern Pydantic v2 schemas).
- **Deploy target**: Talos K8s at `10.70.0.102`, NodePort 30081, registry `10.70.0.30:5000`. All deployments must tolerate the `control-plane` taint (single-node cluster).
- **Repo independence**: cos-docs cannot impose build-time Python deps on sibling repos; per-repo `docs/` and `mkdocs.yml` must be self-contained for that repo's own local preview.
- **GSD workflow**: per `/home/btc/github/CLAUDE.md`, file-changing tools must go through a GSD entry point.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| `mkdocs-monorepo-plugin` with `!include` over git submodules / monorepo restructure | Each repo stays independent; aggregator pulls from sibling paths at build time. Validated by spike 001. | — Pending |
| MkDocs Material + `mkdocstrings[python]` + `griffe-pydantic` | Native rendering of existing Pydantic v2 trailing-string field docstrings (already the COS-Core convention) — zero migration cost. Validated by spike 002. | — Pending |
| Mermaid via `pymdownx.superfences` (Material bundles `mermaid.min.js`) | No extra plugin needed; renders inline in fenced code blocks. Validated by spike 003. | — Pending |
| Multi-stage Dockerfile + Kustomize → Talos NodePort 30081 | Matches `quant-dashboard` deploy pattern; production-equivalent from day one. Validated by spike 004. | — Pending |
| Pin all MkDocs / plugin versions explicitly | Material 2.0 will break all plugins with no migration path; uncontrolled upgrades will silently break the aggregator. | — Pending |
| Defer API-docs strategy (mega-venv vs pre-rendered per-repo CI) to build phase | Both approaches viable; choice depends on aggregator build-time tolerances and CI complexity budget. | — Pending |
| All ~25 repos scaffolded in v1 (not pilot subset) | Solo maintainer; mechanical scaffold + content migration is repetitive but uncomplicated. Better to land the full set than half-finish. | — Pending |
| Full content pass per repo (migrate from README + CLAUDE.md) | Existing READMEs/CLAUDE.md already capture per-repo architecture; restructuring beats stub-then-fill. | — Pending |
| Per-repo Mermaid diagram + top-level workspace diagram | Matches the level of cross-cutting context already in `/home/btc/github/CLAUDE.md`. | — Pending |
| Material default search (lunr) — no custom search/nav tooling in v1 | Solo audience; built-in search across aggregated content is sufficient. | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-18 after initialization*
