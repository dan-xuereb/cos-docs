# Phase 1: Scaffold & Template - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

A `scaffold.sh /path/to/repo` tool that drops a working per-repo MkDocs setup (docs/index.md, docs/architecture.md, docs/api.md, mkdocs.yml, requirements-docs.txt) into a target sibling repo. The scaffolded repo previews locally with `mkdocs serve` — Mermaid renders via `pymdownx.superfences`, Pydantic v2 schemas render natively via `mkdocstrings[python]` + `griffe-pydantic`, all plugin versions pinned. Re-runs are safe.

Phase 1 builds the **tool and template** only. Applying it to all 25 repos and migrating content is Phase 2. Aggregator wiring is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Scaffold Tool Form
- **D-01:** Pure bash script with inline heredocs for templates. Single self-contained file at `cos-docs/scripts/scaffold.sh`. Zero extra deps; matches workspace's existing bash deploy script pattern.
- **D-02:** Templates live as inline heredocs in `scaffold.sh` (not a separate `templates/` directory). Trade-off accepted: longer file, weaker syntax highlighting on template bodies, in exchange for self-containment.
- **D-03:** Invocation pattern: `scaffold.sh /path/to/target-repo` — explicit absolute or relative path. No cwd-based magic.
- **D-04:** v1 is single-repo only. No `--all` batch flag. The 25-repo rollout belongs to Phase 2.

### Idempotency & File Ownership
- **D-05:** File ownership split: `docs/*.md` is **user-owned** (touched only when absent); `mkdocs.yml` and `requirements-docs.txt` are **scaffold-owned** (always overwritten on re-run so template fixes flow through).
- **D-06:** When a scaffold-owned file (mkdocs.yml, requirements-docs.txt) exists with hand edits, scaffold.sh overwrites it and prints a unified diff to stderr so the user can re-apply lost edits.
- **D-07:** "Already scaffolded" detection = presence of `mkdocs.yml` at repo root. None of the 25 sibling repos currently have a pre-existing `mkdocs.yml`, so false-positive risk is zero for v1.
- **D-08:** Single override flag in v1: `--force` overwrites `docs/*.md` too (the normal user-owned protection). No `--dry-run`, no other flags.

### Repo-Type Handling
- **D-09:** Auto-detect repo type from marker files: `pyproject.toml` → python; `package.json` → ts; neither → docs-only. No `--type` flag required.
- **D-10:** Mixed repos (both `pyproject.toml` and `package.json`) are treated as **python primary**. Reflects reality of the workspace — every mixed repo is python-backend with a JS bundler. API docs target Python.
- **D-11:** TypeScript and docs-only repos do **not** get a `docs/api.md` generated. Scaffold drops only `docs/index.md` + `docs/architecture.md` + `mkdocs.yml` + `requirements-docs.txt`. TypeDoc is not in v1 stack, so a TS api.md would just be a stub.

### API Page Bootstrap (Python repos)
- **D-12:** `docs/api.md` is generated with an auto-detected `::: <package_name>` mkdocstrings block, so the page renders meaningful API docs on first `mkdocs serve` with no hand-editing.
- **D-13:** Package name comes from `[project].name` in `pyproject.toml` (PEP 621 standard). Fallback if absent: directory name (e.g. `cos-docs/` → `cos_docs`). No `--package` flag.
- **D-14:** Default mkdocstrings options block in api.md is minimal — `show_root_heading: true`, `members_order: alphabetical`. Matches mkdocstrings docs example. Per-repo customization deferred (user can edit api.md anytime since it's user-owned after first generation).

### Pinned Versions
- **D-15:** Each scaffolded repo gets a standalone `requirements-docs.txt` at its root with all MkDocs Material + plugin versions pinned. Per-repo previews work with `pip install -r requirements-docs.txt && mkdocs serve`. No coupling to the repo's main `pyproject.toml` (which keeps the file usable for TS/docs-only repos too) and no shared file in cos-docs (which would break repo independence).
- **D-16:** Specific pins (locked by spike findings, MUST appear in `requirements-docs.txt`):
  - `mkdocs-material==1.6.1`
  - `mkdocs-monorepo-plugin==<latest stable>` (planner: research exact latest 1.x at plan time)
  - `mkdocstrings[python]==<latest stable>`
  - `griffe-pydantic==<latest stable>`
  - `pymdownx-extensions` is bundled with mkdocs-material, no separate pin needed
- **D-17:** Per-repo `mkdocs.yml` `markdown_extensions` block must include `pymdownx.superfences` with the Mermaid custom_fence so diagrams render.

### Claude's Discretion
- Exact bash heredoc style (EOF vs 'EOF', indented vs left-aligned) — implementer's choice
- Diff output format for D-06 (unified vs side-by-side, color or plain) — implementer's choice
- Smoke test approach: whether scaffold.sh ends with a `mkdocs build --strict` invocation in the target dir as a self-check, or leaves verification to the user — planner can decide based on bash complexity budget

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context (cos-docs)
- `.planning/PROJECT.md` — Stack, constraints, Key Decisions table (versions to pin, gotchas)
- `.planning/REQUIREMENTS.md` — SCAF-01..04, DIAG-01, API-01 are the locked v1 acceptance criteria
- `.planning/ROADMAP.md` §"Phase 1: Scaffold & Template" — Goal + success criteria

### Workspace context
- `/home/btc/github/CLAUDE.md` — workspace overview, naming conventions (snake_case modules, PascalCase classes), tech-stack inventory used by repo-type auto-detection logic
- `/home/btc/github/COS-Core/pyproject.toml` — reference Python repo for testing scaffold (uses Pydantic v2 trailing-string field docstrings, the spike-validated pattern)
- `/home/btc/github/quant-dashboard/package.json` — reference TS repo for testing scaffold's package.json detection path

### Spike findings (validated patterns to follow)
- Spike 001 `monorepo-plugin-aggregation` — `!include` directive (NOT `!import`); use this in mkdocs.yml templates
- Spike 002 `pydantic-mkdocstrings` — `mkdocstrings[python]` + `griffe-pydantic` for Pydantic v2 native rendering
- Spike 003 `mermaid-architecture-diagrams` — `pymdownx.superfences` Mermaid `custom_fence` config; Material bundles `mermaid.min.js` (no extra plugin)
- Spike 004 `talos-nginx-deploy` — out of scope for Phase 1 (relevant to Phase 4)

(Spike READMEs are external to cos-docs/ — referenced by name; concrete file paths are in the spike-findings memory and the user's prior session.)

### External docs (planner reads at plan time)
- mkdocs-material docs: https://squidfunk.github.io/mkdocs-material/ (theme + bundled mermaid behavior)
- mkdocs-monorepo-plugin: https://github.com/backstage/mkdocs-monorepo-plugin (verify `!include` syntax)
- mkdocstrings python handler: https://mkdocstrings.github.io/python/ (options block reference for D-14)
- griffe-pydantic: https://mkdocstrings.github.io/griffe-pydantic/ (Pydantic v2 trailing-string docstring support)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None inside `cos-docs/` itself — this is a greenfield repo (only `README.md` exists).
- `scaffold.sh` will be new code; no existing scripts to extend.

### Established Patterns (workspace-level)
- Workspace uses bash scripts for deploys (e.g. `COS-LangGraph/deploy/apply.sh`, `quant-dashboard/build-images.sh`). `scaffold.sh` should match that style — `#!/usr/bin/env bash`, `set -euo pipefail`, top-of-file usage comment.
- Python repos in workspace standardize on `pyproject.toml` with `[project].name` populated (PEP 621). D-13 detection logic relies on this.
- COS-Core enforces Pydantic v2 trailing-string field docstrings as a convention — this is exactly what griffe-pydantic renders, so spike 002's setup will "just work" against COS-Core when used as the Phase 1 smoke-test target.

### Integration Points
- Scaffolded `mkdocs.yml` files become the `!include` targets that the Phase 3 aggregator will consume. The site_name and nav structure chosen in Phase 1 templates locks the per-repo navigation that Phase 3 surfaces.
- `requirements-docs.txt` location (repo root) must remain stable so Phase 4 CI can `pip install -r` against it during aggregator builds.

</code_context>

<specifics>
## Specific Ideas

- Inline heredoc style chosen explicitly to keep scaffold.sh as a single-file artifact — match the readability of `quant-dashboard/build-images.sh`.
- Diff-on-overwrite (D-06) is the maintainer-facing "what did I lose?" affordance — no rollback, just visibility.
- COS-Core is the natural smoke-test target: it's pure-Python, has Pydantic v2 with trailing-string docstrings, and will exercise mkdocstrings + griffe-pydantic + Mermaid all at once.

</specifics>

<deferred>
## Deferred Ideas

- `--all` batch mode for scaffold.sh → Phase 2 (Content Migration) responsibility; Phase 2 may use a thin wrapper loop instead.
- `--dry-run` flag → not in v1; revisit if Phase 2 bulk runs prove risky.
- Per-page mkdocstrings options heavier than the minimal D-14 default → user-owned api.md edits, not a scaffold concern.
- TypeDoc / typedoc-plugin-markdown for TS repos → not in v1 stack; would be a future requirement (CIR-* family).
- A `mkdocs build --strict` smoke check at the end of scaffold.sh — left to planner discretion (Claude's Discretion above).

</deferred>

---

*Phase: 01-scaffold-template*
*Context gathered: 2026-04-18*
