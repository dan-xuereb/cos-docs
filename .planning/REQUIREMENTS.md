# Requirements: cos-docs

**Defined:** 2026-04-18
**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

## v1 Requirements

### Scaffold

- [ ] **SCAF-01**: A `scaffold.sh` script drops `docs/index.md`, `docs/architecture.md`, `docs/api.md`, and `mkdocs.yml` into a target sibling repo
- [ ] **SCAF-02**: The per-repo `mkdocs.yml` template includes correct `!include`-compatible config (site_name, nav, plugins) so the repo can be previewed locally with `mkdocs serve`
- [ ] **SCAF-03**: The scaffold pins MkDocs Material and plugin versions explicitly in a per-repo requirements file
- [x] **SCAF-04**: Re-running `scaffold.sh` on an already-scaffolded repo is safe (no clobbering existing edited content) — completed in Plan 01-01 (32a5cf5); idempotency, --force override, and empty-diff suppression all smoke-verified

### Content

- [ ] **CONT-01**: All ~25 sibling repos in `/home/btc/github/` are scaffolded
- [ ] **CONT-02**: Each repo's `docs/index.md` summarizes purpose, language/runtime, and entry points (sourced from existing `README.md` + `CLAUDE.md`)
- [ ] **CONT-03**: Each repo's `docs/architecture.md` contains a Mermaid diagram of that repo's internal structure plus a written architecture overview (sourced from `CLAUDE.md` where present)
- [ ] **CONT-04**: Each repo's `docs/api.md` exposes that repo's primary public API surface (modules / classes / functions), rendered via `mkdocstrings[python]` for Python repos

### Aggregator

- [x] **AGGR-01**: The aggregator `mkdocs.yml` in `cos-docs/` uses `mkdocs-monorepo-plugin` with `!include ../<repo>/mkdocs.yml` entries for all 25 repos (29 in final count; 03-01)
- [x] **AGGR-02**: Aggregator navigation groups repos by domain: Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure (03-01)
- [ ] **AGGR-03**: Aggregator includes a top-level `docs/index.md` workspace overview and a top-level `docs/architecture.md` with a workspace-wide Mermaid data-flow diagram
- [x] **AGGR-04**: `mkdocs build` from `cos-docs/` produces a complete static site with no broken `!include` references and no missing-anchor warnings (03-01 strict-build exit 0)
- [x] **AGGR-05**: Material default search (lunr) works across all aggregated content with no extra plugin (03-01; `search` plugin active)

### Diagrams

- [ ] **DIAG-01**: Mermaid fenced code blocks render in both per-repo and aggregator builds via `pymdownx.superfences` and Material's bundled `mermaid.min.js` (no extra plugin)
- [ ] **DIAG-02**: At least one Mermaid architecture diagram exists per non-exempt repo (in `docs/architecture.md`). Exempt repos (no software architecture to diagram): `COS-Hardware`, `COS-Network`, `COS-Capability-Gated-Agent-Architecture`. Exempt list maintained in `cos-docs/scripts/scaffold-all.sh` (DIAGRAM_EXEMPT array); additions during Phase 2 authoring update both that array and this requirement footnote.
- [ ] **DIAG-03**: A top-level workspace data-flow Mermaid diagram exists in the aggregator

### API Docs

- [ ] **API-01**: Pydantic v2 models with trailing-string field docstrings render their field docs natively via `mkdocstrings[python]` + `griffe-pydantic`
- [ ] **API-02**: API-docs strategy decision is recorded as a Key Decision in `PROJECT.md` before deploy phase begins (mega-venv vs pre-rendered per-repo CI)
- [ ] **API-03**: The chosen API-docs strategy is implemented and produces complete API pages for all Python repos

### Deploy

- [ ] **DEPLOY-01**: A multi-stage `Dockerfile` builds the static site in one stage and serves it from nginx in a runtime stage
- [ ] **DEPLOY-02**: A Kustomize bundle in `cos-docs/k8s/` deploys the container to the Talos cluster at `10.70.0.102` with NodePort 30081
- [ ] **DEPLOY-03**: The deployment tolerates the `control-plane` taint (single-node cluster) and uses the private registry `10.70.0.30:5000`
- [ ] **DEPLOY-04**: The site is reachable at `http://10.70.0.102:30081/` after a successful deploy

### CI

- [ ] **CI-01**: A GitHub Actions workflow in `cos-docs/` rebuilds the aggregator nightly
- [ ] **CI-02**: The same workflow rebuilds on push to `main` and supports `workflow_dispatch`
- [ ] **CI-03**: A successful CI run pushes the built image to the private registry (or produces a deployable artifact)

## v2 Requirements

### Per-Repo CI

- **CIR-01**: Each scaffolded repo gets a `mkdocs.yml` lint check on push (so broken includes are caught at the source repo, not the aggregator)
- **CIR-02**: Per-repo doc preview deploys (PR previews) for major repos

### Quality

- **QUAL-01**: Linkcheck across the aggregated site
- **QUAL-02**: Doc-as-test (verify code samples in docs still execute)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Versioned docs (`mike`) | Single "latest" is enough for solo use; versioning adds rebuild complexity without payoff |
| Auth on the K8s site | Internal-only network, no login wall needed |
| Public DNS / TLS / ingress | NodePort access only; cert-manager + ingress is out of scope |
| External / public hosting polish (SEO, marketing nav) | Audience is the maintainer (solo) |
| Cross-repo search beyond Material default (lunr) | Built-in search is sufficient for v1 |
| Curated tags plugin / tuned navigation | Material default nav is enough |
| Migrating workspace to monorepo tooling | Each repo stays an independent git repo (architectural constraint) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 1 | Pending |
| SCAF-02 | Phase 1 | Pending |
| SCAF-03 | Phase 1 | Pending |
| SCAF-04 | Phase 1 | Pending |
| DIAG-01 | Phase 1 | Pending |
| API-01 | Phase 1 | Pending |
| CONT-01 | Phase 2 | Pending |
| CONT-02 | Phase 2 | Pending |
| CONT-03 | Phase 2 | Pending |
| CONT-04 | Phase 2 | Pending |
| DIAG-02 | Phase 2 | Pending |
| AGGR-01 | Phase 3 | Complete (03-01) |
| AGGR-02 | Phase 3 | Complete (03-01) |
| AGGR-03 | Phase 3 | Pending |
| AGGR-04 | Phase 3 | Complete (03-01) |
| AGGR-05 | Phase 3 | Complete (03-01) |
| DIAG-03 | Phase 3 | Pending |
| API-02 | Phase 3 | Pending |
| API-03 | Phase 3 | Pending |
| DEPLOY-01 | Phase 4 | Pending |
| DEPLOY-02 | Phase 4 | Pending |
| DEPLOY-03 | Phase 4 | Pending |
| DEPLOY-04 | Phase 4 | Pending |
| CI-01 | Phase 4 | Pending |
| CI-02 | Phase 4 | Pending |
| CI-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 26 total (recount during roadmap creation; original summary said 23)
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 — traceability populated by roadmap creation*
