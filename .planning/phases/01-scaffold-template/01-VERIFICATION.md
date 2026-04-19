---
phase: 01-scaffold-template
verified: 2026-04-18T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (programmatically); 1 of 5 ROADMAP success criteria requires live-browser verification
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Mermaid SVG actually renders in a browser (DIAG-01 visual verification)"
    expected: "After `mkdocs serve` against a freshly-scaffolded repo, opening the architecture page in a browser shows a rendered Mermaid SVG diagram (a flowchart with Input → Process → Output → Storage nodes), NOT raw text or an empty container"
    why_human: "Static-build verification only confirms the `class=\"mermaid\"` container element is present in HTML. Mermaid is rendered client-side by `mermaid.min.js` at page load — only a real browser session can confirm the SVG actually paints. SUMMARY claims Material bundles mermaid.min.js but did not visually verify it runs."
  - test: "`mkdocs serve` (not just `mkdocs build --strict`) starts cleanly and serves the site"
    expected: "`mkdocs serve` from a freshly-scaffolded repo starts on http://127.0.0.1:8000, serves index/architecture/api pages, and a browser session loads them without console errors"
    why_human: "ROADMAP success criterion #2 specifies `mkdocs serve` literally; the E2E smoke used `mkdocs build --strict` (the SUMMARY explicitly says 'stricter than serve' but they exercise different code paths — `serve` adds the live-reload server and watcher). No archived evidence that `serve` itself was invoked."
---

# Phase 1: Scaffold & Template — Verification Report

**Phase Goal:** A maintainer can run `scaffold.sh <repo>` and get a working, locally-previewable per-repo docs tree with pinned MkDocs Material + plugins, Mermaid rendering, and Pydantic-aware API rendering wired in.

**Verified:** 2026-04-18
**Status:** human_needed (5/5 programmatic must-haves PASS; 2 visual/runtime items require human confirmation)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `scaffold.sh <target-repo>` creates docs/index.md, docs/architecture.md, docs/api.md (Python only), mkdocs.yml, requirements-docs.txt | VERIFIED | Live re-run during this verification produced all 5 files in `/tmp/verify-phase1-*` (see Bash output above). For non-Python repos, api.md is correctly omitted (D-11). |
| 2 | `mkdocs serve` previews freshly-scaffolded repo with no missing-plugin errors | PARTIAL — needs human | E2E smoke ran `mkdocs build --strict` (per SUMMARY 01-02 step) which exits 0. `serve` itself was not invoked in archived smoke. Build-strict is functionally equivalent for plugin resolution but ROADMAP wording says `serve`. |
| 3 | Mermaid fenced block renders as SVG in local preview | PARTIAL — needs human | Static HTML grep confirmed `class="mermaid"` container present 1× in `site/architecture/index.html`. SVG is generated client-side by `mermaid.min.js`. Material bundles this script by default per Spike 003. Visual confirmation in a browser still required. |
| 4 | Pydantic v2 model with trailing-string field docstrings renders FIELD docs (not just class names) on docs/api.md | VERIFIED | SUMMARY 01-02 reports the `Lowercase exchange name` substring (the OHLCVBar.exchange field docstring from `/home/btc/github/COS-Core/src/cos_core/models/market.py:16`) appears 4× in built `site/api/index.html`. Verified emit_mkdocs_yml has `extensions: [griffe_pydantic]` AND `show_submodules: true` in the handler block (commit `ded6955`); without these the field docs would not render. |
| 5 | Re-running scaffold.sh on already-scaffolded repo does not clobber edited docs/*.md content | VERIFIED | Plan 01-01 smoke case 4 verified hand-edited docs/index.md survived re-run (no --force); case 5 verified --force does overwrite; case 7 verified empty-diff suppression. Logic in `write_user_owned()` at scaffold.sh:227-242 correctly returns early on existing file when FORCE=0. |

**Score:** 5/5 truths VERIFIED programmatically; 2 of these have visual/runtime aspects flagged for human verification.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `cos-docs/scripts/scaffold.sh` | Pure-bash, executable, single-file scaffold tool with all emit_* bodies populated | VERIFIED | 305 lines, executable (-rwxrwxr-x), `bash -n` clean, no `TODO:` strings remain. Implements D-01..D-17. |
| `docs/index.md` (in target) | User-owned overview template | VERIFIED | Live smoke produced 350 bytes; contains "user-owned" marker. |
| `docs/architecture.md` (in target) | Sample Mermaid `flowchart LR` inside triple-backtick `mermaid` fence | VERIFIED | Live smoke produced 373 bytes; fenced block present (Input → Process → Output → Storage). |
| `docs/api.md` (in target, Python only) | mkdocstrings `:::` autodoc directive with auto-detected package name (underscore form) | VERIFIED | Live smoke produced `::: cos_core` (NOT `cos-core`); D-13 normalization wired end-to-end. |
| `mkdocs.yml` (in target) | Material theme + nav + mkdocstrings handler (with griffe_pydantic ext + show_submodules) + pymdownx.superfences Mermaid custom_fence | VERIFIED | Live smoke output contains all required blocks. python-only API nav line conditionally present. |
| `requirements-docs.txt` (in target) | 4 pinned packages per D-16, mkdocs-material >= 9.0 | VERIFIED | Live smoke shows: mkdocs-material==9.7.6, mkdocs-monorepo-plugin==1.1.2, mkdocstrings[python]==1.0.4, griffe-pydantic==1.3.1. None in 1.x series. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| scaffold.sh | target_repo/pyproject.toml | sed -nE on `[project].name`, hyphen-to-underscore normalize | WIRED | scaffold.sh:96-109 (`detect_python_package`); live smoke confirmed `cos-core` → `cos_core`. |
| scaffold.sh | target_repo/mkdocs.yml | scaffold-owned overwrite + diff | WIRED | scaffold.sh:247-270 (`write_scaffold_owned`); empty-diff suppression confirmed Plan 01-01 case 7. |
| scaffold.sh emit_mkdocs_yml | pymdownx.superfences Mermaid custom_fence (D-17) | heredoc body | WIRED | scaffold.sh:204-209; verbatim `format: !!python/name:pymdownx.superfences.fence_code_format`. |
| scaffold.sh emit_api_md | mkdocstrings `:::` block (D-12, D-14) | heredoc body with $PKG interpolation | WIRED | scaffold.sh:151-164; `::: ${pkg}` directive present. |
| scaffold.sh emit_requirements_docs_txt | D-16 pinned versions (resolved at scaffold-time) | heredoc body | WIRED | scaffold.sh:212-219; literal pins baked in. |
| scaffold.sh main() | emit_mkdocs_yml call site (BOTH site_name AND repo_type) | write_scaffold_owned wrapper | WIRED | scaffold.sh:298 — `write_scaffold_owned "mkdocs.yml" emit_mkdocs_yml "$site_name" "$repo_type"`. Both args passed. |
| mkdocs.yml mkdocstrings handler | griffe_pydantic extension + show_submodules (API-01 critical) | YAML config in heredoc | WIRED | scaffold.sh:197-199; both lines present. Without these, API-01 would silently fail (SUMMARY 01-02 documents this as the Rule 1+2 fix in commit `ded6955`). |

### Data-Flow Trace (Level 4)

Not applicable — Phase 1 deliverable is a code-generation tool (bash script that writes files), not a runtime data-rendering surface. The "data flow" here is template-substitution at scaffold-time, which is verified by inspecting actual generated output (above).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Script syntax valid | `bash -n /home/btc/github/cos-docs/scripts/scaffold.sh` | exit 0, no output | PASS |
| Script is executable | `[ -x /home/btc/github/cos-docs/scripts/scaffold.sh ]` | true | PASS |
| Live scaffold against COS-Core pyproject.toml | `scaffold.sh /tmp/verify-phase1-XXX` (with COS-Core pyproject) | All 5 files written, correct content | PASS |
| D-13 normalization wired | `grep '^::: cos_core$' /tmp/.../docs/api.md && ! grep '^::: cos-core$' ...` | Match for `cos_core`, no match for `cos-core` | PASS |
| D-17 Mermaid custom_fence emitted | `grep -E 'custom_fences|name: mermaid|pymdownx.superfences' generated_mkdocs.yml` | All three present | PASS |
| D-16 pin freshness (mkdocs-material >= 9.0) | `grep mkdocs-material== generated_requirements-docs.txt` | `mkdocs-material==9.7.6` | PASS |
| API-01 wiring (griffe_pydantic + show_submodules) | `grep -E 'griffe_pydantic|show_submodules' generated_mkdocs.yml` | Both present | PASS |
| `mkdocs build --strict` against COS-Core | (per SUMMARY 01-02) | exit 0, build in 0.84s, no warnings | PASS (archived only) |
| `mkdocs serve` works | not run | n/a | SKIPPED — see human_verification |
| Mermaid SVG actually paints in browser | not run (no headless browser invoked) | n/a | SKIPPED — see human_verification |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SCAF-01 | 01-01 | scaffold.sh drops docs/index.md, docs/architecture.md, docs/api.md, mkdocs.yml | SATISFIED | Live smoke this verification |
| SCAF-02 | 01-02 | mkdocs.yml template includes correct site_name, nav, plugins for `mkdocs serve` | SATISFIED (build-strict proxy) | E2E smoke build --strict; `serve` itself flagged for human |
| SCAF-03 | 01-02 | scaffold pins MkDocs Material + plugin versions in per-repo requirements file | SATISFIED | requirements-docs.txt has all 4 pinned with `==`, mkdocs-material in 9.x |
| SCAF-04 | 01-01 | Re-running scaffold.sh is safe (no clobbering) | SATISFIED | Plan 01-01 smoke case 4; --force case 5; empty-diff case 7 |
| DIAG-01 | 01-02 | Mermaid fenced blocks render via pymdownx.superfences + bundled mermaid.min.js | SATISFIED (HTML proxy) | `class="mermaid"` container present in built HTML; visual SVG paint flagged for human |
| API-01 | 01-02 | Pydantic v2 trailing-string field docstrings render via mkdocstrings + griffe-pydantic | SATISFIED | `Lowercase exchange name` (OHLCVBar.exchange field docstring) appears 4× in built api page (per SUMMARY 01-02 Task 2 evidence). Critically, the griffe_pydantic extension and show_submodules are wired into the template (commit `ded6955`) — without these the SUMMARY documents the field docs would NOT render. |

All 6 phase requirement IDs are SATISFIED. No orphans (REQUIREMENTS.md table confirms only SCAF-01..04, DIAG-01, API-01 mapped to Phase 1, and the plan frontmatter declares all six across Plans 01-01 + 01-02).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| scaffold.sh | n/a | No `TODO:` / `FIXME:` markers | — | Clean |
| scaffold.sh | n/a | No empty-return placeholders | — | All emit_* functions have substantive heredoc bodies |
| scaffold.sh | n/a | No console.log-only / placeholder-only handlers | — | Clean |

No blocker, warning, or info-level anti-patterns found in scaffold.sh. The empty-diff suppression in `write_scaffold_owned` (scaffold.sh:258-263) is a deliberate UX feature, not an empty branch.

### Human Verification Required

#### 1. Browser-render Mermaid SVG

**Test:** From a freshly-scaffolded Python repo (e.g., a copy of COS-Core), run:
```
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-docs.txt
pip install -e .
mkdocs serve
```
Then open http://127.0.0.1:8000/architecture/ in a browser.

**Expected:** The "Sample data flow diagram" section displays a rendered Mermaid SVG flowchart with four nodes (Input, Process, Output, Storage) connected by arrows — NOT raw `flowchart LR\n A[Input] --> B[Process]...` text and NOT an empty box.

**Why human:** Mermaid renders client-side via `mermaid.min.js`. Static-build verification only confirms the `class="mermaid"` container element exists. Confirming the SVG actually paints requires a real browser session.

#### 2. `mkdocs serve` succeeds (not just `mkdocs build --strict`)

**Test:** From a freshly-scaffolded repo, run `mkdocs serve` and confirm the dev server starts on port 8000 with no plugin-loading errors in the console; navigate index → architecture → api in a browser; confirm no JS console errors.

**Expected:** Server prints `Serving on http://127.0.0.1:8000/`; all three pages load; live-reload watcher works.

**Why human:** ROADMAP success criterion #2 specifies `mkdocs serve` literally. The archived E2E smoke ran `mkdocs build --strict` instead (per SUMMARY 01-02) — these exercise overlapping but not identical code paths (serve adds the file watcher and dev-server). Confirming `serve` itself works closes the literal-criterion gap.

### Gaps Summary

No structural gaps in the delivered scaffold.sh. All artifacts exist with substantive content, all key links between functions/heredocs/main() are wired, all 6 Phase 1 requirements are programmatically satisfied, and the live re-run during this verification reproduced the SUMMARY-claimed output exactly. The two human-verification items are about confirming runtime/browser behavior that cannot be checked statically — they do not represent missing implementation.

The single notable risk surfaced: SUMMARY 01-02 documents that without the `extensions: [griffe_pydantic]` and `show_submodules: true` lines (which were missing from the original CONTEXT.md spec D-14), `mkdocs build --strict` would silently succeed while API-01 SILENTLY fails (only class names render, field docs are dropped). The fix is in (commit `ded6955`, scaffold.sh:197-199), but downstream agents reading CONTEXT.md D-14 in Phase 2/3 may re-introduce the gap. The SUMMARY 01-02 "Open Items" already flags this as a recommendation to update CONTEXT.md — worth tracking.

---

*Verified: 2026-04-18*
*Verifier: Claude (gsd-verifier)*
