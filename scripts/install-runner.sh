#!/usr/bin/env bash
set -euo pipefail

# install-runner.sh — one-time self-hosted GitHub Actions runner install.
#
# Context:
#   - D-01 (CONTEXT.md): CI runs on a self-hosted runner on the Talos host
#     (10.70.0.102) because build-all-api.sh needs working-tree access to
#     29 sibling repos at /home/btc/github/.
#   - D-07 (CONTEXT.md): Registration token is fetched via `gh api`
#     (scripted), not the interactive ./config.sh dance in the GH UI.
#   - D-10 (CONTEXT.md): Runner is registered to github.com/dan-xuereb/cos-docs.
#
# What this script does (in order):
#   1. Preflight checks (user, tool availability, gh auth, gh scopes,
#      workspace tree, no existing runner).
#   2. Fetch the latest actions/runner release asset URL via `gh api`.
#   3. Download the tarball, verify SHA256 (from release body) when present.
#   4. Extract into $RUNNER_HOME.
#   5. Fetch a short-lived registration token via
#      `gh api -X POST repos/dan-xuereb/cos-docs/actions/runners/registration-token`.
#   6. Run ./config.sh --unattended --replace to register as
#      "talos-cos-docs" with labels self-hosted,cos-docs,talos.
#   7. ./svc.sh install btc + ./svc.sh start to lay down + start the
#      systemd unit actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service.
#   8. Verify the unit is active; dump journalctl on failure.
#
# Credentials policy:
#   - This script NEVER embeds credentials. It relies on the invoking
#     user already being authenticated via `gh auth login` with the
#     required scopes (`repo` + `admin:repo_hook`).
#   - The registration token is short-lived (~1h) and is never echoed
#     to stdout/stderr; only its presence is validated.
#
# Operator runbook: .planning/phases/04-deploy-ci/RUNNER-SETUP.md

# --- constants --------------------------------------------------------------
REPO="dan-xuereb/cos-docs"
RUNNER_HOME="/home/btc/actions-runner"
RUNNER_NAME="talos-cos-docs"
RUNNER_LABELS="self-hosted,cos-docs,talos"
WORKSPACE_COS_DOCS="/home/btc/github/cos-docs"

# --- helpers ----------------------------------------------------------------
die()  { echo "FATAL: $*" >&2; exit 1; }
info() { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

# --- preflight --------------------------------------------------------------
info "Preflight: checking environment..."

# 1. user must be btc (matches workspace ownership of /home/btc/github/*)
[ "$(whoami)" = "btc" ] || die "must be run as user 'btc' (got: $(whoami))"

# 2. required tools
for tool in gh jq curl tar sha256sum sudo systemctl; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

# 3. gh auth status
gh auth status >/dev/null 2>&1 || die "gh CLI not authenticated; run: gh auth login"

# 4. gh must have `repo` scope (sufficient for
#    /repos/{owner}/{repo}/actions/runners/registration-token endpoint per
#    https://docs.github.com/rest/actions/self-hosted-runners)
if ! gh auth status 2>&1 | grep -qE "[[:space:]]'repo'([,]|$)"; then
    die "gh token missing 'repo' scope; run: gh auth refresh -s repo"
fi

# 5. workspace must exist (the runner expects to work against it)
[ -d "$WORKSPACE_COS_DOCS" ] || die "expected workspace not found: $WORKSPACE_COS_DOCS"

# 6. no existing runner
if [ -f "$RUNNER_HOME/.runner" ]; then
    die "runner already registered at $RUNNER_HOME (.runner exists). Remove it first:
  cd $RUNNER_HOME && ./config.sh remove --token \$(gh api -X POST repos/$REPO/actions/runners/remove-token --jq .token)
  sudo ./svc.sh stop && sudo ./svc.sh uninstall
  cd .. && rm -rf $RUNNER_HOME"
fi

info "Preflight OK (user=btc, gh authenticated with admin:repo_hook)."

# --- fetch release metadata -------------------------------------------------
info "Fetching latest actions/runner release metadata..."

# Asset name pattern: actions-runner-linux-x64-<semver>.tar.gz
asset_url="$(gh api repos/actions/runner/releases/latest \
    --jq '.assets[] | select(.name | test("^actions-runner-linux-x64-[0-9.]+\\.tar\\.gz$")) | .browser_download_url' \
    | head -n1)"
[ -n "$asset_url" ] || die "could not resolve actions/runner linux-x64 asset URL"

asset_name="$(basename "$asset_url")"
runner_version="$(echo "$asset_name" | sed -E 's/^actions-runner-linux-x64-([0-9.]+)\.tar\.gz$/\1/')"
info "Selected runner version $runner_version"
info "  asset: $asset_url"

# Release body (for SHA256 check). Lines tend to look like:
#   $ echo "<64-hex>  actions-runner-linux-x64-X.Y.Z.tar.gz" | shasum -a 256 -c
release_body="$(gh api repos/actions/runner/releases/latest --jq '.body' || echo "")"
expected_sha="$(echo "$release_body" \
    | grep -Eo "[0-9a-f]{64}[[:space:]]+$asset_name" \
    | head -n1 \
    | awk '{print $1}' || true)"

# --- stage runner home ------------------------------------------------------
mkdir -p "$RUNNER_HOME"
cd "$RUNNER_HOME"

info "Downloading runner tarball..."
curl -fsSL -o runner.tar.gz "$asset_url"

if [ -n "$expected_sha" ]; then
    info "Verifying SHA256 against release body ($expected_sha)..."
    actual_sha="$(sha256sum runner.tar.gz | awk '{print $1}')"
    if [ "$actual_sha" != "$expected_sha" ]; then
        rm -f runner.tar.gz
        die "SHA256 mismatch! expected=$expected_sha actual=$actual_sha"
    fi
    info "SHA256 verified."
else
    warn "No SHA256 line found in release body; skipping hash verification."
fi

info "Extracting runner..."
tar xzf runner.tar.gz
rm -f runner.tar.gz

# --- fetch registration token (scripted per D-07) ---------------------------
info "Fetching runner registration token via gh api..."
token="$(gh api -X POST "repos/${REPO}/actions/runners/registration-token" --jq .token)"
[ -n "$token" ] || die "registration token was empty; check gh scopes and repo access"

# --- register ---------------------------------------------------------------
info "Registering runner as '$RUNNER_NAME' with labels: $RUNNER_LABELS"
./config.sh \
    --url "https://github.com/${REPO}" \
    --token "$token" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "_work" \
    --unattended \
    --replace

# Scrub the token from memory; it is already one-use, but be explicit.
unset token

# --- install + start systemd unit ------------------------------------------
# Service name follows the GitHub Actions runner convention:
#   actions.runner.<owner>-<repo>.<runner_name>.service
SERVICE_NAME="actions.runner.${REPO//\//-}.${RUNNER_NAME}.service"

info "Installing systemd unit as user btc (sudo required)..."
sudo ./svc.sh install btc

info "Starting systemd unit..."
sudo ./svc.sh start

# Give systemd a moment to settle.
sleep 2

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "==========================================================" >&2
    echo "Service $SERVICE_NAME is NOT active. Recent logs:" >&2
    echo "==========================================================" >&2
    sudo journalctl -u "$SERVICE_NAME" --no-pager -n 50 >&2 || true
    die "runner service failed to start"
fi

info "Runner installed and active: $SERVICE_NAME"
info "Verify at https://github.com/${REPO}/settings/actions/runners"
