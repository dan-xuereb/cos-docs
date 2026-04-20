---
phase: 04-deploy-ci
type: runbook
audience: operator
created: 2026-04-19
---

# Self-Hosted GitHub Actions Runner Setup — Talos Host

**Purpose:** One-time install of a self-hosted `actions/runner` on the Talos host
(10.70.0.102) so that `runs-on: self-hosted` workflows in
`github.com/dan-xuereb/cos-docs` can access `/home/btc/github/*` and push to
the internal registry at `10.70.0.30:5000`.

**Who runs this:** The maintainer (user `btc`), once, on 10.70.0.102.

**Locked decisions backing this runbook:**

- **D-01:** Self-hosted runner on the Talos host as a systemd service (CI needs
  working-tree access to 29 sibling repos at `/home/btc/github/`).
- **D-07:** Registration via scripted `gh api`, not the interactive paste-token
  dance in the GitHub Actions Runners UI.
- **D-10:** Runner registered to `github.com/dan-xuereb/cos-docs`.

---

## Prerequisites

Run these **before** executing `scripts/install-runner.sh`:

1. **User identity.** SSH (or open a local terminal) to 10.70.0.102 as user `btc`.
   `whoami` must print `btc`. The script aborts otherwise.

2. **Tooling on PATH.**
   ```bash
   for t in gh jq curl tar sha256sum sudo systemctl; do
       command -v "$t" >/dev/null || echo "MISSING: $t"
   done
   ```
   All should resolve silently.

3. **`gh` CLI authenticated with the required scopes.**
   The `POST /repos/{owner}/{repo}/actions/runners/registration-token` endpoint
   requires the `admin:repo_hook` scope (in addition to the default `repo`).

   ```bash
   gh auth status
   # If not logged in:
   gh auth login
   # If logged in but missing admin:repo_hook:
   gh auth refresh -s admin:repo_hook
   # Confirm:
   gh auth status 2>&1 | grep admin:repo_hook
   ```

4. **Workspace tree exists.** `/home/btc/github/cos-docs/` must be cloned and on
   `main`. The runner doesn't check out into this path (it uses its own
   `_work/` tree), but the workflow script relies on `/home/btc/github/` being
   populated with all 29 sibling repos.

5. **No pre-existing runner** at `/home/btc/actions-runner/`.
   If one exists, uninstall first (see [Uninstall](#uninstall-rare) below).

6. **Disk.** The actions runner tarball is ~180 MB extracted; the `_work/`
   directory will grow with each job (logs + workflow temp files). Allow ≥1 GB
   free under `/home/btc/`.

7. **Sudo.** `svc.sh install btc` requires sudo to drop the systemd unit into
   `/etc/systemd/system/`. You will be prompted once.

---

## Install Steps

```bash
# 1. SSH / terminal as btc on 10.70.0.102:
whoami   # -> btc

# 2. From anywhere (the installer chdirs into /home/btc/actions-runner itself):
cd /home/btc/github/cos-docs

# 3. Run the installer:
./scripts/install-runner.sh
```

Expected output tail:

```
==> Runner installed and active: actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service
==> Verify at https://github.com/dan-xuereb/cos-docs/settings/actions/runners
```

The installer:

- Preflights user / tools / gh auth / gh scopes.
- Picks the latest `actions/runner` linux-x64 release via `gh api`.
- Downloads the tarball and verifies its SHA256 against the GitHub
  release body (T-04-03-01 mitigation — aborts on mismatch).
- Fetches a short-lived registration token via `gh api`
  (`-X POST repos/dan-xuereb/cos-docs/actions/runners/registration-token`).
- Runs `./config.sh --unattended --replace --name talos-cos-docs --labels
  self-hosted,cos-docs,talos --work _work`.
- Calls `sudo ./svc.sh install btc && sudo ./svc.sh start`.
- Verifies the systemd unit is `active` and dumps `journalctl` if not.

The registration token is **never** echoed to the console and is unset before
the script exits.

---

## Verification

After the installer prints the "Runner installed and active" line:

1. **systemd is running the unit:**
   ```bash
   systemctl is-active actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service
   # -> active
   ```

2. **GitHub UI shows the runner as Idle:**
   Open <https://github.com/dan-xuereb/cos-docs/settings/actions/runners>.
   Expect a row named `talos-cos-docs` with labels `self-hosted`, `cos-docs`,
   `talos` and status **Idle** (green dot).

3. **Runner work directory is isolated from the workspace tree:**
   ```bash
   ls -d /home/btc/actions-runner/_work
   # -> /home/btc/actions-runner/_work    (created on first job)
   ```
   This is deliberate — the runner's `_work/` must be **distinct** from
   `/home/btc/github/cos-docs/`. The workflow `cd`s into
   `/home/btc/github/cos-docs/` at its first step so that `build-all-api.sh`
   can find the 29 sibling repos as peers. See RESEARCH.md §3
   "Working-directory strategy" for why `actions/checkout` is deliberately
   bypassed.

4. **Manifest generator runs (sanity check):**
   ```bash
   cd /home/btc/github/cos-docs
   ./scripts/emit-site-manifest.sh | jq -e '.repos | length >= 25'
   # -> true
   ```

---

## Troubleshooting

### Preflight: `admin:repo_hook scope missing`

```bash
gh auth refresh -s admin:repo_hook
# re-run the installer
```

### Preflight: `runner already registered at /home/btc/actions-runner`

The installer refuses to overwrite. See [Uninstall](#uninstall-rare).

### `SHA256 mismatch!`

Do **not** bypass — delete `$RUNNER_HOME` and retry. A mismatch means the
tarball was corrupted in flight or (worse) tampered with. If the GitHub
release body has no hash line, the installer warns and proceeds — this is
rare but not fatal.

### Service not active

```bash
SVC=actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service
sudo journalctl -u "$SVC" -n 100 --no-pager
sudo systemctl status "$SVC"
```

Common causes:

- **Registration token expired** between `config.sh` and `svc.sh start`
  (tokens are short-lived, typically ~1 hour; normally not an issue).
  Re-run the installer after `./config.sh remove` (see Uninstall).
- **Token scope wrong** — `gh auth status` should show `admin:repo_hook`.
- **Network loss** to `api.github.com` during the `./run.sh` listen loop.

### Runner appears Offline in the GitHub UI

- Check `systemctl is-active …` on the host — if `active`, the runner may be
  re-establishing its long-poll connection; wait 30s.
- If persistently Offline: `sudo systemctl restart "$SVC"` and re-check.

---

## Uninstall (rare)

```bash
SVC=actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service
REPO=dan-xuereb/cos-docs

cd /home/btc/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Remove-token is a separate endpoint from registration-token.
./config.sh remove --token "$(gh api -X POST "repos/${REPO}/actions/runners/remove-token" --jq .token)"

cd ..
rm -rf /home/btc/actions-runner
```

After this, the runner disappears from the GitHub Actions Runners UI and the
systemd unit file is removed from `/etc/systemd/system/`.

---

## Reference

- `cos-docs/scripts/install-runner.sh` — the installer this runbook drives.
- `cos-docs/.planning/phases/04-deploy-ci/04-RESEARCH.md` §3
  "Self-hosted Runner Setup" and "Working-directory strategy" — background
  rationale and the `_work/` isolation requirement.
- CONTEXT.md D-01 / D-07 / D-10 — locked decisions this runbook implements.
- GitHub docs: <https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners>
