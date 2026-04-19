#!/usr/bin/env bash
set -euo pipefail

# scaffold-all.sh — Iterate ROLLOUT_LIST, applying Phase 1 scaffold.sh per repo.
# Per-repo: preflight → scaffold → uv venv → pip install -r requirements-docs.txt
#         → (Python repos) pip install -e . → mkdocs build --strict → git add+commit.
# Continues on per-repo failure (D-03); prints greppable summary at end.
# Implements decisions D-01..D-17 from .planning/phases/02-content-migration/02-CONTEXT.md.
#
# Usage: scaffold-all.sh
#   No flags. (Per CONTEXT.md: --force is intentionally NOT exposed here — see
#   Pitfall 6 in 02-RESEARCH.md. To re-stamp scaffold-owned files for a single
#   repo, run scaffold.sh /path/to/repo directly.)
#
# NOTE: This wrapper does NOT push to any remote. All commits stay local;
# the maintainer reviews and pushes manually.

WORKSPACE="${WORKSPACE:-/home/btc/github}"
SCAFFOLD_SH="$(cd "$(dirname "$0")" && pwd)/scaffold.sh"
LOG_DIR="$(mktemp -d -t scaffold-all.XXXXXX)"

# ---------------------------------------------------------------------------
# ROLLOUT_LIST — exactly 30 entries per D-14 (verbatim from 02-CONTEXT.md):
# "Authoritative repo list = 31 repos on disk in /home/btc/github/, MINUS
# COS-electrs (Rust, out of stack) = 30 repos."
#
# Audit: enumerate by walking 02-RESEARCH.md §"Repo Inventory" table rows in
# order, then drop the row for COS-electrs. The result MUST be exactly 30 names.
#
# Two entries below are auto-skipped at preflight via the EXCLUDE_LIST: cos-docs
# (aggregator self-reference) and capability-gated-agent-architecture (lowercase
# duplicate of COS-Capability-Gated-Agent-Architecture per D-12). They are
# enumerated here for the D-14 audit-count completeness — the EXCLUDE_LIST is
# the runtime guard.
#
# COS-Core is NOT in this list — it lacks its own .git directory; it lives
# inside the parent /home/btc/github git repo and was scaffolded in Phase 1
# as part of that parent commit. Revisit only if Phase 1's COS-Core scaffold
# needs replay (run scaffold.sh /home/btc/github/COS-Core directly — not via
# this wrapper).
# ---------------------------------------------------------------------------

ROLLOUT_LIST=(
    bis-forge
    bls-forge
    BTC-Forge
    capability-gated-agent-architecture        # auto-skip via EXCLUDE_LIST (D-12 dup)
    coinbase_websocket_BTC_pricefeed
    COS-Bitcoin-Protocol-Intelligence-Platform
    COS-BTC-Network-Crawler
    COS-BTC-Node
    COS-BTC-SQL-Warehouse
    COS-BTE
    COS-Capability-Gated-Agent-Architecture
    COS-CIE
    cos-data-access
    cos-docs                                   # auto-skip via EXCLUDE_LIST (aggregator self-ref)
    COS-Hardware
    COS-Infra
    COS-LangGraph
    COS-MSE
    COS-Network
    COS-SGL
    cos-signal-bridge
    cos-signal-explorer
    cos-webpage
    EDGAR-Forge
    FRED-Forge
    imf-forge
    ingest
    OrbWeaver
    quant-dashboard
    stooq-forge
    # COS-electrs intentionally omitted per D-14 (Rust, out of stack).
    # COS-Core is NOT in this list — it lacks its own .git directory; lives
    # inside the parent /home/btc/github git repo and was scaffolded in Phase 1.
)

# EXCLUDE_LIST: members of ROLLOUT_LIST that are listed for D-14 audit-count
# completeness but must NEVER be scaffolded. Preflight short-circuits these.
declare -A EXCLUDE_LIST=()
EXCLUDE_LIST[cos-docs]="aggregator self-reference (would clobber its own mkdocs.yml)"
EXCLUDE_LIST[capability-gated-agent-architecture]="D-12: lowercase duplicate of COS-Capability-Gated-Agent-Architecture"

# Audit guard: ROLLOUT_LIST MUST contain exactly 30 entries to satisfy D-14.
if [ "${#ROLLOUT_LIST[@]}" -ne 30 ]; then
    echo "[scaffold-all] FATAL: ROLLOUT_LIST has ${#ROLLOUT_LIST[@]} entries; D-14 requires exactly 30." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# D-09: diagram-exempt repos (no software architecture to diagram).
# Used by the content-authoring plan (02-03), surfaced here for visibility/grep.
# ---------------------------------------------------------------------------
DIAGRAM_EXEMPT=( COS-Hardware COS-Network COS-Capability-Gated-Agent-Architecture )

# ---------------------------------------------------------------------------
# D-17: distribution-name (pyproject [project].name) != importable module name.
# Verified mismatches (from 02-RESEARCH.md Failure Mode 1):
# ---------------------------------------------------------------------------
declare -A PACKAGE_OVERRIDES=()
PACKAGE_OVERRIDES[COS-LangGraph]=langgraph_agent
# Implementer: at first wrapper run, monitor mkdocs-build logs for additional
# `Could not collect '<module>'` warnings; add the true module name here
# and re-run scaffold.sh /path/to/repo --package <name> for the affected repo.

# ---------------------------------------------------------------------------
# Per-repo status accumulator (D-03 continue-on-failure summary)
# ---------------------------------------------------------------------------
declare -A REPO_STATUS=()

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

preflight() {
    local repo_path="$1"
    local repo_name="$2"
    # Hard exclusions (D-12, aggregator self-reference) — short-circuit before any git ops.
    if [ -n "${EXCLUDE_LIST[$repo_name]:-}" ]; then
        echo "EXCLUDED: ${EXCLUDE_LIST[$repo_name]}"
        return 1
    fi
    [ -d "$repo_path" ]      || { echo "missing dir"; return 1; }
    [ -d "$repo_path/.git" ] || { echo "not a git repo"; return 1; }
    local branch
    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    # D-15: main OR master are acceptable; anything else is skipped.
    if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
        echo "branch=${branch} (D-15: expects main or master)"
        return 1
    fi
    # D-16: skip dirty trees, never auto-stash.
    if [ -n "$(git -C "$repo_path" status --porcelain 2>/dev/null)" ]; then
        echo "dirty working tree (D-16: never auto-stash)"
        return 1
    fi
    return 0
}

invoke_scaffold() {
    local repo_path="$1"
    local repo_name="$2"
    local override="${PACKAGE_OVERRIDES[$repo_name]:-}"
    if [ -n "$override" ]; then
        "$SCAFFOLD_SH" --package "$override" "$repo_path"
    else
        "$SCAFFOLD_SH" "$repo_path"
    fi
}

build_smoke() {
    local repo_path="$1"
    (
        cd "$repo_path" || exit 1
        # Ephemeral per-repo venv (D-15 repo-independence; uv per workspace standard)
        rm -rf .venv-docs
        uv venv --quiet .venv-docs >/dev/null
        uv pip install --quiet --python .venv-docs/bin/python -r requirements-docs.txt >/dev/null
        # For Python repos, install the package itself so mkdocstrings can import it.
        # Per Pitfall 5 in 02-RESEARCH.md, this is required not optional.
        if [ -f pyproject.toml ]; then
            uv pip install --quiet --python .venv-docs/bin/python -e . >/dev/null
        fi
        .venv-docs/bin/mkdocs build --strict
    )
}

commit_scaffold() {
    local repo_path="$1"
    # Pitfall 3: explicit file paths only — never blanket-add the working tree.
    # Add api.md only if it exists (TS / docs-only repos don't get one).
    local files=( docs/index.md docs/architecture.md mkdocs.yml requirements-docs.txt )
    if [ -f "$repo_path/docs/api.md" ]; then
        files+=( docs/api.md )
    fi
    git -C "$repo_path" add "${files[@]}"
    # Pitfall 6 wording: honest commit message — content comes later in 02-03.
    git -C "$repo_path" commit -m "docs: add cos-docs scaffold (content to follow)"
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

echo "[scaffold-all] workspace=$WORKSPACE log_dir=$LOG_DIR" >&2
echo "[scaffold-all] iterating ${#ROLLOUT_LIST[@]} repos (D-14 audit: 30)" >&2

for repo in "${ROLLOUT_LIST[@]}"; do
    path="$WORKSPACE/$repo"
    echo "=== $repo ===" >&2

    if reason=$(preflight "$path" "$repo"); then
        : # ok
    else
        REPO_STATUS["$repo"]="SKIP: ${reason}"
        continue
    fi

    if ! invoke_scaffold "$path" "$repo" > "$LOG_DIR/${repo}.scaffold.log" 2>&1; then
        REPO_STATUS["$repo"]="FAIL: scaffold (see $LOG_DIR/${repo}.scaffold.log)"
        continue
    fi

    if ! build_smoke "$path" > "$LOG_DIR/${repo}.build.log" 2>&1; then
        REPO_STATUS["$repo"]="FAIL: mkdocs build --strict (see $LOG_DIR/${repo}.build.log)"
        continue
    fi

    if ! commit_scaffold "$path" > "$LOG_DIR/${repo}.commit.log" 2>&1; then
        REPO_STATUS["$repo"]="FAIL: git commit (see $LOG_DIR/${repo}.commit.log)"
        continue
    fi

    REPO_STATUS["$repo"]="OK"
done

# Greppable summary (CONTEXT.md "Specifics" line)
echo
echo "=== scaffold-all.sh summary ==="
printf "%-50s %s\n" "REPO" "STATUS"
printf "%-50s %s\n" "----" "------"
for repo in "${ROLLOUT_LIST[@]}"; do
    printf "%-50s %s\n" "$repo" "${REPO_STATUS[$repo]:-UNKNOWN}"
done
echo
echo "Per-repo logs: $LOG_DIR"
echo "Tip: grep '^[A-Za-z].*FAIL\\|SKIP' for action items."

# Exit 0 even on per-repo failures (D-03 continue-on-failure semantics).
exit 0
