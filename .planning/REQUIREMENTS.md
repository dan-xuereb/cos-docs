# Requirements: cos-docs

**Defined:** 2026-04-18
**Core Value:** A single URL where every COS / Xuer Capital repo's architecture, API, and diagrams are searchable and cross-linked — built from per-repo `docs/` trees that live next to the code they describe.

## v1 Requirements

### Scaffold

- [ ] **SCAF-01**: A `scaffold.sh` script drops `docs/index.md`, `docs/architecture.md`, `docs/api.md`, and `mkdocs.yml` into a target sibling repo
- [ ] **SCAF-02**: The per-repo `mkdocs.yml` template includes correct `!include`-compatible config (site_name, nav, plugins) so the repo can be previewed locally with `mkdocs serve`
- [ ] **SCAF-03**: The scaffold pins MkDocs Material and plugin versions explicitly in a per-repo requirements file
- [ ] **SCAF-04**: Re-running `scaffold.sh` on an already-scaffolded repo is safe (no clobbering existing edited content)

### Content

- [ ] **CONT-01**: All ~25 sibling repos in `/home/btc/github/` are scaffolded
- [ ] **CONT-02**: Each repo's `docs/index.md` summarizes purpose, language/runtime, and entry points (sourced from existing `README.md` + `CLAUDE.md`)
- [ ] **CONT-03**: Each repo's `docs/architecture.md` contains a Mermaid diagram of that repo's internal structure plus a written architecture overview (sourced from `CLAUDE.md` where present)
- [ ] **CONT-04**: Each repo's `docs/api.md` exposes that repo's primary public API surface (modules / classes / functions), rendered via `mkdocstrings[python]` for Python repos

### Aggregator

- [ ] **AGGR-01**: The aggregator `mkdocs.yml` in `cos-docs/` uses `mkdocs-monorepo-plugin` with `!include ../<repo>/mkdocs.yml` entries for all 25 repos
- [ ] **AGGR-02**: Aggregator navigation groups repos by domain: Forges, Signal Stack, Agent, Presentation, Warehouse, Network, Schema, Infrastructure
- [ ] **AGGR-03**: Aggregator includes a top-level `docs/index.md` workspace overview and a top-level `docs/architecture.md` with a workspace-wide Mermaid data-flow diagram
- [ ] **AGGR-04**: `mkdocs build` from `cos-docs/` produces a complete static site with no broken `!include` references and no missing-anchor warnings
- [ ] **AGGR-05**: Material default search (lunr) works across all aggregated content with no extra plugin

### Diagrams

- [ ] **DIAG-01**: Mermaid fenced code blocks render in both per-repo and aggregator builds via `pymdownx.superfences` and Material's bundled `mermaid.min.js` (no extra plugin)
- [ ] **DIAG-02**: At least one Mermaid architecture diagram exists per repo (in `docs/architecture.md`)
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
| (Populated during roadmap creation) | — | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 0
- Unmapped: 23 ⚠️ (until roadmap is created)

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 after initial definition*
