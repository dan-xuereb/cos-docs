# Phase 1: Scaffold & Template - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 01-scaffold-template
**Areas discussed:** Scaffold tool form, Idempotency strategy, Repo-type handling, API page bootstrap

---

## Scaffold Tool Form

### Q: What form should scaffold.sh take?

| Option | Description | Selected |
|--------|-------------|----------|
| Pure bash + heredocs | Single self-contained script in cos-docs/scripts/scaffold.sh. Templates inline as heredocs. Zero extra deps. | ✓ |
| Python + Jinja2 templates | scaffold.py with templates/ dir. Cleaner template editing, adds python dep. | |
| Cookiecutter / copier | Industry-standard template engines. Powerful but extra third-party tool. | |

### Q: Where do template files live?

| Option | Description | Selected |
|--------|-------------|----------|
| Inline heredocs in scaffold.sh | Self-contained script. | ✓ |
| Separate cos-docs/templates/ dir | Two places to keep in sync. | |

### Q: How is scaffold.sh invoked against a target repo?

| Option | Description | Selected |
|--------|-------------|----------|
| Path argument: scaffold.sh /path/to/repo | Explicit, no surprise. | ✓ |
| Run from inside target repo | cd repo && /path/to/scaffold.sh . | |
| Both (default cwd, accept arg) | Most flexible. | |

### Q: Should scaffold.sh also support batch mode (apply to all sibling repos)?

| Option | Description | Selected |
|--------|-------------|----------|
| v1: single-repo only | Phase 2 handles the all-25 rollout. | ✓ |
| Add --all flag now | Walks /home/btc/github/ siblings. | |

---

## Idempotency Strategy

### Q: Who 'owns' the per-repo files after scaffolding?

| Option | Description | Selected |
|--------|-------------|----------|
| docs/*.md user-owned, mkdocs.yml + reqs scaffold-owned | Re-runs always overwrite mkdocs.yml/reqs; touch docs/*.md only if absent. | ✓ |
| All files user-owned after first scaffold | Re-runs skip everything that exists. | |
| All files scaffold-owned, --force needed | Strictest. | |

### Q: When a scaffold-owned file (mkdocs.yml) has been hand-edited, what happens on re-run?

| Option | Description | Selected |
|--------|-------------|----------|
| Overwrite + show diff to stderr | Always update; print what changed. | ✓ |
| Detect drift and prompt y/n | Interactive. | |
| Save .bak and overwrite silently | Backup the old file. | |

### Q: How does scaffold.sh detect 'already scaffolded'?

| Option | Description | Selected |
|--------|-------------|----------|
| Presence of mkdocs.yml at repo root | Simple; zero false-positive risk in workspace. | ✓ |
| Marker file: .cos-docs-scaffold | Explicit but adds a stray file in every repo. | |
| Header comment in generated files | Fragile if reformatted. | |

### Q: Any explicit override flags needed in v1?

| Option | Description | Selected |
|--------|-------------|----------|
| --force (overwrite docs/*.md too) | Single escape hatch. | ✓ |
| --force + --dry-run | Adds dry-run safety. | |
| No flags | Default behavior only. | |

---

## Repo-Type Handling

### Q: How does scaffold.sh determine repo type (Python / TS / docs)?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect from pyproject.toml / package.json | Zero-flag UX. | ✓ |
| Require --type python\|ts\|docs flag | Explicit. | |
| Single unified template, type-agnostic | Same docs/api.md regardless. | |

### Q: How to handle repos with BOTH pyproject.toml and package.json (mixed)?

| Option | Description | Selected |
|--------|-------------|----------|
| Treat as python primary | All known mixed repos are python-primary. | ✓ |
| Generate api.md sections for both | TypeDoc isn't in v1 stack. | |
| Skip api.md entirely | Defer to user per repo. | |

### Q: What does docs/api.md look like for a TypeScript or docs-only repo?

| Option | Description | Selected |
|--------|-------------|----------|
| Skip api.md generation | TypeDoc isn't in v1 stack; docs-only have no API. | ✓ |
| Placeholder api.md with 'TODO' content | Symmetry but creates 25 stub files of cruft. | |
| Generate api.md only when type=python | Same as first option but explicit. | |

---

## API Page Bootstrap

### Q: What goes in docs/api.md by default for Python repos?

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detected `::: package.name` mkdocstrings stub | Working API page on first scaffold. | ✓ |
| Empty placeholder with comment instructions | TODO-style file. | |
| Stub for top-level package + import-graph TOC | Most output but risk of overwhelm. | |

### Q: How is the package name detected from pyproject.toml?

| Option | Description | Selected |
|--------|-------------|----------|
| Parse [project].name | Standard PEP 621 field. | ✓ |
| Parse [tool.hatch.build.targets.wheel].packages | Hatch-specific. | |
| User specifies via --package flag | Explicit per-invocation. | |

### Q: Default mkdocstrings options block in api.md?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: show_root_heading + members_order alphabetical | Sane defaults. | ✓ |
| Heavy: show_signature, show_source, separate_signature, full member tree | More info but verbose. | |
| No options block; rely on global mkdocs.yml plugins config | Cleanest content but less per-page control. | |

### Q: Where does the per-repo MkDocs version pin live?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-repo `requirements-docs.txt` | Standalone file at repo root. | ✓ |
| Add docs extra to pyproject.toml [project.optional-dependencies] | Pollutes pyproject; doesn't work for non-Python. | |
| Single shared file in cos-docs/, repos symlink | Breaks repo independence. | |

---

## Claude's Discretion

- Bash heredoc style (EOF vs 'EOF', indentation) — implementer's choice.
- Diff output format on overwrite — implementer's choice.
- Whether scaffold.sh self-runs `mkdocs build --strict` against the target as a smoke check — planner discretion.

## Deferred Ideas

- `--all` batch mode → Phase 2 (Content Migration).
- `--dry-run` flag → not in v1; revisit if Phase 2 bulk runs prove risky.
- TypeDoc for TS repos → future v2 requirement.
- Per-page mkdocstrings option richness → user-owned, not a scaffold concern.
