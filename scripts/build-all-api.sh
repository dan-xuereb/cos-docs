#!/usr/bin/env bash
set -euo pipefail

# build-all-api.sh — pre-render each Python sibling repo's docs/api.md
# via its own isolated .venv-docs so that the mkdocstrings output can be
# consumed by the cos-docs aggregator build (which does NOT load
# mkdocstrings — see mkdocs-monorepo-plugin upstream issue #73).
#
# Contract (D-03): Phase 4 CI matrix will wrap the inner per-repo body,
# not replace it. Continue-on-failure; exit 0; greppable summary.
# The swap-in-place of docs/api.md is TRANSIENT — each repo's original
# declarative `::: <module>` content is backed up and restored at the
# end of the run. Aggregator build happens separately AFTER this script
# finishes; a small coordination window exists where each repo's api.md
# is temporarily the HTML passthrough form.
#
# Usage:
#   cos-docs/scripts/build-all-api.sh            # run full sweep (restores originals)
#   cos-docs/scripts/build-all-api.sh --keep     # keep swap-in (for aggregator build)
#   cos-docs/scripts/build-all-api.sh --restore  # restore originals only
#
# Typical workflow (coordinator script / future Makefile):
#   build-all-api.sh --keep    # pre-render, leave api.md swapped
#   (cd cos-docs && mkdocs build --strict)   # aggregator build consumes swapped api.md
#   build-all-api.sh --restore # restore originals (reset per-repo git state)

WORKSPACE="${WORKSPACE:-/home/btc/github}"
COS_DOCS="${COS_DOCS:-$WORKSPACE/cos-docs}"
LOG_DIR="$(mktemp -d -t build-all-api.XXXXXX)"
MODE="${1:-full}"   # full | --keep | --restore

# ---------------------------------------------------------------------------
# PYTHON_REPOS — sibling repos with pyproject.toml + docs/api.md (20 entries).
# Audit-verified 2026-04-19 by:
#   for r in /home/btc/github/*/; do [ -f "$r/pyproject.toml" ] && echo "$(basename $r)"; done
# ---------------------------------------------------------------------------
PYTHON_REPOS=(
    bis-forge
    bls-forge
    BTC-Forge
    COS-Bitcoin-Protocol-Intelligence-Platform
    COS-BTC-Network-Crawler
    COS-BTC-SQL-Warehouse
    COS-BTE
    COS-CIE
    COS-Core
    cos-data-access
    COS-LangGraph
    COS-MSE
    COS-SGL
    cos-signal-bridge
    cos-signal-explorer
    EDGAR-Forge
    FRED-Forge
    imf-forge
    ingest
    stooq-forge
)

if [ "${#PYTHON_REPOS[@]}" -ne 20 ]; then
    echo "[build-all-api] FATAL: PYTHON_REPOS has ${#PYTHON_REPOS[@]} entries; expected 20." >&2
    exit 2
fi

# NO_DEPS_INSTALL — empirical evidence from 02-02-SUMMARY.md: workspace-dep
# packages (xuer-sgl, cos-sdl) are not on PyPI. These repos install with
# `pip install --no-deps -e .` instead of `-e .`.
declare -A NO_DEPS_INSTALL=()
NO_DEPS_INSTALL[COS-CIE]=1             # needs xuer-sgl (not on PyPI)
NO_DEPS_INSTALL[cos-signal-bridge]=1   # needs cos-sdl  (not on PyPI)

declare -A REPO_STATUS=()

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

backup_api_md() {
    local repo_path="$1"
    local api_md="$repo_path/docs/api.md"
    local backup="$repo_path/docs/api.md.pre-render-backup"
    if [ -f "$api_md" ] && [ ! -f "$backup" ]; then
        cp -p "$api_md" "$backup"
    fi
}

restore_api_md() {
    local repo_path="$1"
    local api_md="$repo_path/docs/api.md"
    local backup="$repo_path/docs/api.md.pre-render-backup"
    if [ -f "$backup" ]; then
        mv "$backup" "$api_md"
    fi
}

append_gitignore_if_missing() {
    # Open Question 3 resolution: idempotent append of .venv-docs, .api-staging, site/
    local repo_path="$1"
    local gi="$repo_path/.gitignore"
    touch "$gi"
    for entry in ".venv-docs/" ".api-staging/" "site/" "docs/api.md.pre-render-backup"; do
        grep -qxF "$entry" "$gi" || echo "$entry" >> "$gi"
    done
}

build_and_stage() {
    local repo="$1"
    local repo_path="$WORKSPACE/$repo"
    local log="$LOG_DIR/$repo.log"

    if [ ! -d "$repo_path" ]; then
        REPO_STATUS[$repo]="FAIL: path-missing"
        return
    fi
    if [ ! -f "$repo_path/docs/api.md" ]; then
        REPO_STATUS[$repo]="SKIP: no-docs-api-md"
        return
    fi

    append_gitignore_if_missing "$repo_path"
    backup_api_md "$repo_path"

    (
        cd "$repo_path" || exit 1
        rm -rf .venv-docs .api-staging
        uv venv --quiet .venv-docs >/dev/null
        uv pip install --quiet --python .venv-docs/bin/python -r requirements-docs.txt >/dev/null

        if [ -n "${NO_DEPS_INSTALL[$repo]:-}" ]; then
            uv pip install --quiet --python .venv-docs/bin/python --no-deps -e . >/dev/null
        else
            uv pip install --quiet --python .venv-docs/bin/python -e . >/dev/null
        fi

        .venv-docs/bin/mkdocs build --strict -d .api-staging

        python3 - "$repo_path" <<'PY_EXTRACT'
import sys, re, pathlib
root = pathlib.Path(sys.argv[1])
html_path = root / ".api-staging" / "api" / "index.html"
if not html_path.exists():
    sys.exit(f"FATAL: no {html_path} — per-repo mkdocs build did not emit api/")
src = html_path.read_text(encoding="utf-8")
m = re.search(r'<article[^>]*md-content__inner[^>]*>(.*?)</article>', src, re.DOTALL)
if not m:
    sys.exit(f"FATAL: no <article ... md-content__inner> block found in {html_path}")
body = m.group(1).strip()
api_md = root / "docs" / "api.md"
tmp = api_md.with_suffix(".md.tmp")
# md_in_html passthrough: markdown="0" tells Python-Markdown not to reparse the inner HTML
content = f'# API\n\n<div class="cos-docs-prerendered-api" markdown="0">\n{body}\n</div>\n'
tmp.write_text(content, encoding="utf-8")
tmp.replace(api_md)
print(f"[staged] {api_md}")
PY_EXTRACT

    ) >"$log" 2>&1 && REPO_STATUS[$repo]="OK" || REPO_STATUS[$repo]="FAIL: build-or-extract (see $log)"

    # Teardown the per-repo venv + staging dir regardless of outcome (space-efficient).
    rm -rf "$repo_path/.venv-docs" "$repo_path/.api-staging" 2>/dev/null || true
}

restore_all() {
    for repo in "${PYTHON_REPOS[@]}"; do
        restore_api_md "$WORKSPACE/$repo"
    done
}

# ---------------------------------------------------------------------------
# Mode dispatch
# ---------------------------------------------------------------------------

if [ "$MODE" = "--restore" ]; then
    restore_all
    echo "[build-all-api] Restored originals for all ${#PYTHON_REPOS[@]} repos."
    exit 0
fi

# Main sweep
for repo in "${PYTHON_REPOS[@]}"; do
    echo "=== $repo ===" >&2
    build_and_stage "$repo"
done

# Write greppable status file (mirrors Phase 2 02-ROLLOUT-STATUS.md pattern).
STATUS_FILE="$COS_DOCS/.build-all-api-status.md"
{
    echo "# build-all-api.sh status — $(date -Iseconds)"
    echo
    echo "| Repo | Status |"
    echo "|------|--------|"
    for repo in "${PYTHON_REPOS[@]}"; do
        printf "| %s | %s |\n" "$repo" "${REPO_STATUS[$repo]:-UNKNOWN}"
    done
    echo
    echo "Per-repo build logs: $LOG_DIR"
} > "$STATUS_FILE.tmp"
mv "$STATUS_FILE.tmp" "$STATUS_FILE"

# Stdout summary
echo
echo "=== build-all-api.sh summary ==="
printf "%-50s %s\n" "REPO" "STATUS"
for repo in "${PYTHON_REPOS[@]}"; do
    printf "%-50s %s\n" "$repo" "${REPO_STATUS[$repo]:-UNKNOWN}"
done
echo
echo "Status file: $STATUS_FILE"
echo "Per-repo logs: $LOG_DIR"

if [ "$MODE" = "--keep" ]; then
    echo
    echo "[build-all-api] --keep mode: per-repo docs/api.md swapped to pre-rendered HTML."
    echo "[build-all-api] Run 'cd cos-docs && mkdocs build --strict' now."
    echo "[build-all-api] When done: $0 --restore"
else
    # Default (no --keep): restore originals so per-repo git state is unchanged after run.
    restore_all
    echo "[build-all-api] Restored originals (use --keep to leave swapped)."
fi

exit 0   # continue-on-failure semantics (D-03)
