#!/usr/bin/env bash
set -euo pipefail

# emit-site-manifest.sh — emit site-manifest.json per D-02 contract.
#
# Walks the workspace root (default /home/btc/github) and emits a JSON
# document to STDOUT with the following shape:
#
#   {
#     "generated_at": "2026-04-19T12:34:56Z",
#     "cos_docs_sha": "<40-hex or 'unknown'>",
#     "repos": {
#       "<repo-basename>": "<40-hex or 'unknown'>",
#       ...
#     }
#   }
#
# Rules:
#   - cos-docs itself is excluded from `repos` (it has its own top-level SHA).
#   - Non-git directories (no .git/ subdir) are skipped silently.
#   - git rev-parse HEAD failures yield "unknown" (never aborts the script).
#   - cos_docs_sha prefers $GITHUB_SHA (CI), falls back to local HEAD,
#     else "unknown".
#   - Only JSON goes to stdout; warnings go to stderr.
#
# References:
#   - Phase 4 D-02 (CONTEXT.md): "continue-on-failure + SHA manifest"
#   - Phase 4 D-10 (CONTEXT.md): repo is github.com/dan-xuereb/cos-docs
#   - scripts/pull-all.sh: canonical sibling-iteration pattern
#
# Usage:
#   ./scripts/emit-site-manifest.sh                        # default workspace
#   ./scripts/emit-site-manifest.sh --workspace /some/path
#   ./scripts/emit-site-manifest.sh | jq -e .              # verify JSON validity

WORKSPACE="/home/btc/github"

# --- arg parsing ------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --workspace)
            [ $# -ge 2 ] || { echo "error: --workspace requires a path" >&2; exit 2; }
            WORKSPACE="$2"
            shift 2
            ;;
        --workspace=*)
            WORKSPACE="${1#--workspace=}"
            shift
            ;;
        -h|--help)
            sed -n '3,30p' "$0"
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

[ -d "$WORKSPACE" ] || { echo "error: workspace not a directory: $WORKSPACE" >&2; exit 1; }

# --- resolve top-level fields -----------------------------------------------
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cos_docs_sha="${GITHUB_SHA:-}"
if [ -z "$cos_docs_sha" ]; then
    if [ -d "$WORKSPACE/cos-docs/.git" ]; then
        cos_docs_sha="$(git -C "$WORKSPACE/cos-docs" rev-parse HEAD 2>/dev/null || echo "unknown")"
    else
        cos_docs_sha="unknown"
    fi
fi

# --- build sibling sha stream ----------------------------------------------
# Newline-delimited "name<TAB>sha" stream; jq parses it into {key,value} pairs.
stream_siblings() {
    local dir name sha
    for dir in "$WORKSPACE"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        [ "$name" = "cos-docs" ] && continue
        [ -d "$dir/.git" ] || continue
        sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")"
        printf '%s\t%s\n' "$name" "$sha"
    done
}

# --- emit JSON --------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    stream_siblings | jq -Rn \
        --arg generated_at "$generated_at" \
        --arg cos_docs_sha "$cos_docs_sha" \
        '[inputs | split("\t") | {key: .[0], value: .[1]}]
         | from_entries
         | {generated_at: $generated_at, cos_docs_sha: $cos_docs_sha, repos: .}'
else
    # Belt-and-braces fallback: hand-rolled JSON. jq should always be present
    # on the runner host, but don't let its absence break the build.
    echo "warning: jq not found; falling back to hand-rolled JSON emitter" >&2
    {
        printf '{\n'
        printf '  "generated_at": "%s",\n' "$generated_at"
        printf '  "cos_docs_sha": "%s",\n' "$cos_docs_sha"
        printf '  "repos": {\n'
        first=1
        while IFS=$'\t' read -r name sha; do
            [ -z "$name" ] && continue
            if [ "$first" -eq 1 ]; then
                first=0
            else
                printf ',\n'
            fi
            # Repo basenames and 40-hex SHAs need no JSON escaping under
            # current workspace conventions (no quotes, backslashes, control
            # chars in basenames).
            printf '    "%s": "%s"' "$name" "$sha"
        done < <(stream_siblings)
        printf '\n  }\n'
        printf '}\n'
    }
fi
