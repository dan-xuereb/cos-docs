---
phase: 04-deploy-ci
plan: 03
subsystem: ci
tags: [github-actions, self-hosted-runner, systemd, site-manifest, runner-install, talos]

requires:
  - phase: 04-deploy-ci
    provides: "scripts/build-all-api.sh (from plan 03-02) — runner must be able to execute this against /home/btc/github/* siblings, which is why the runner is self-hosted on the Talos host per D-01"
provides:
  - "scripts/emit-site-manifest.sh — reproducible per-repo SHA manifest generator invoked by the Plan 04-04 workflow and baked into every image per D-02/D-10"
  - "scripts/install-runner.sh — documentation-as-code install script for the self-hosted runner on the Talos host per D-07 (scripted gh api registration)"
  - "RUNNER-SETUP.md — operator runbook (prerequisites, steps, troubleshooting, uninstall)"
  - "Running systemd service actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service on 10.70.0.102 with labels self-hosted,cos-docs,talos (Idle on GitHub)"
affects: [04-04 workflow targets runs-on self-hosted with those labels, 04-05 E2E deploy verification]

tech-stack:
  added:
    - "GitHub Actions self-hosted runner 2.333.1 (linux-x64)"
    - "systemd unit actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service"
  patterns:
    - "Scripted runner registration via gh api (D-07) — no manual copy of the registration token from GitHub UI"
    - "Runner work directory /home/btc/actions-runner/_work/ isolated from /home/btc/github/cos-docs/ (CI never pollutes the docs source tree)"
    - "jq-built JSON manifest: deterministic key escaping + ordering; stderr for logs, stdout for JSON only"
    - "Documentation-as-code: install-runner.sh is both runnable on the host AND the canonical record of the install procedure"

key-files:
  created:
    - "scripts/emit-site-manifest.sh"
    - "scripts/install-runner.sh"
    - ".planning/phases/04-deploy-ci/RUNNER-SETUP.md"
  modified:
    - "scripts/install-runner.sh (in-flight Rule-2 fix — scope tightening)"

key-decisions:
  - "gh auth scope requirement relaxed from admin:repo_hook → repo. GitHub's POST /repos/{owner}/{repo}/actions/runners/registration-token endpoint requires only the repo scope; admin:repo_hook governs webhook admin and is orthogonal. Standard `gh auth login` default scopes (repo,workflow,gist,read:org) now satisfy install-runner.sh preflight without an extra `gh auth refresh -s admin:repo_hook` device-code round trip."
  - "Registration token is fetched via gh api (HTTPS, minutes-long TTL, single-use) and never echoed to logs — mitigates T-04-03-03 (spoofing)."
  - "Runner installed as user btc (T-04-03-02 accepted): matches workspace norms, required for sibling-repo read/write during build-all-api.sh swap/restore; scoping to a dedicated user would require refactoring the workspace."

patterns-established:
  - "Install scripts emit a service-name guard: `systemctl is-active <svc>` post-install, with `journalctl -u <svc> --no-pager -n 50` dump on failure — reusable for any future runner / daemon install on the Talos host."
  - "emit-site-manifest.sh's `--workspace PATH` flag + `$GITHUB_SHA`-aware cos_docs_sha resolution makes the same script work identically from a laptop, the runner host, and inside a CI step."

requirements-completed: []  # CI-01/02/03 remain Pending — this plan provides the runner + manifest script that the Plan 04-04 workflow (CI-01/02) and Plan 04-05 E2E (CI-03) consume. See "Requirement Closeout" below.

duration: ~45min (including operator-in-the-loop install + inline scope fix)
completed: 2026-04-20
---

# Phase 04 Plan 03: Self-Hosted Runner Install + Site Manifest Summary

**Two scripts and an operator runbook: `emit-site-manifest.sh` (reproducible per-repo SHA manifest), `install-runner.sh` (scripted gh-api runner registration per D-07), and `RUNNER-SETUP.md` (operator runbook) — culminating in a live systemd-managed self-hosted runner on Talos 10.70.0.102 Idle at github.com/dan-xuereb/cos-docs with labels `self-hosted,cos-docs,talos`. Unblocks the Plan 04-04 `runs-on: self-hosted` workflow that build-all-api.sh requires per D-01.**

## Performance

- **Duration:** ~45 min end-to-end (authoring + verification + operator install + in-flight fix)
- **Tasks:** 3/3 (2 autonomous + 1 human-action checkpoint)
- **Files created:** 3 (`scripts/emit-site-manifest.sh`, `scripts/install-runner.sh`, `.planning/phases/04-deploy-ci/RUNNER-SETUP.md`)
- **Files modified:** 1 (`scripts/install-runner.sh` — Rule-2 scope-check relaxation)

## Accomplishments

- `scripts/emit-site-manifest.sh` (122 lines, executable) — emits valid JSON with `generated_at`, `cos_docs_sha`, and `repos` (31 sibling repos discovered; exceeds the >=25 plan threshold). cos-docs itself excluded; unknown-SHA fallback for non-git dirs; `--workspace` flag + `$GITHUB_SHA` awareness.
- `scripts/install-runner.sh` (170 lines, executable) — preconditions check, GH release metadata fetch, SHA256 verification, tar extract, `gh api`-scoped registration token, `config.sh` unattended register, `svc.sh install btc && start`, post-install `systemctl is-active` gate.
- `.planning/phases/04-deploy-ci/RUNNER-SETUP.md` (220 lines) — operator runbook: prerequisites, step-by-step install, troubleshooting, uninstall.
- **Runner live.** Operator executed `install-runner.sh` on 10.70.0.102 as user `btc`; `sudo svc.sh install btc && sudo svc.sh start` completed interactively (sudo prompt). `systemctl is-active actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` → `active`. Runner visible at github.com/dan-xuereb/cos-docs Settings → Actions → Runners with version 2.333.1 and labels `self-hosted,cos-docs,talos`.
- **Post-install verification:** `./scripts/emit-site-manifest.sh | jq -r '.repos | length, .cos_docs_sha, .generated_at'` → `31`, `3c9daa9...` (40-hex), `2026-04-20T14:47:55Z` — all green.

## Task Commits

| Task | Name | Branch | Commit | Files |
|------|------|--------|--------|-------|
| 1 | scripts/emit-site-manifest.sh | main | `acc1d7b` | `scripts/emit-site-manifest.sh` |
| 2 | install-runner.sh + RUNNER-SETUP.md | main | `040926e` | `scripts/install-runner.sh`, `.planning/phases/04-deploy-ci/RUNNER-SETUP.md` |
| 2-fix | Rule-2 in-flight scope relaxation | main | `3c9daa9` | `scripts/install-runner.sh` |
| 3 | Operator runs install-runner.sh on Talos | — | (host-side install; no repo commit) | systemd unit + ~/actions-runner/ on 10.70.0.102 |

All commits on `main`; no `kubernetes` branch touches (unlike 04-02).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] gh auth scope over-strict — relaxed admin:repo_hook → repo**

- **Found during:** Task 3 (operator running install-runner.sh on the Talos host)
- **Issue:** install-runner.sh preconditions aborted with `admin:repo_hook scope required` even though the operator's `gh auth status` already showed `repo` scope. Plan had inherited the `admin:repo_hook` requirement from 04-CONTEXT.md `user_setup.dashboard_config`, but that scope governs webhook admin — it is NOT required by the runner-registration-token API. Per [GitHub REST API docs for POST /repos/{owner}/{repo}/actions/runners/registration-token](https://docs.github.com/en/rest/actions/self-hosted-runners), only the `repo` scope (or fine-grained `administration: write`) is needed.
- **Fix:** Changed the scope check in `install-runner.sh` from `grep -q admin:repo_hook` to a check that accepts any of (`repo`, `admin:repo_hook`, or a fine-grained-PAT indicator), with the error-path message now suggesting `gh auth refresh -s repo` as the remedy.
- **Impact:** Standard `gh auth login` default scopes (`repo,workflow,gist,read:org`) now satisfy the preflight — no extra device-code round trip required.
- **Files modified:** `scripts/install-runner.sh`
- **Commit:** `3c9daa9` on main — `fix(04-03): accept 'repo' scope instead of 'admin:repo_hook' for runner reg`
- **Operator retry:** After commit, operator re-ran `./scripts/install-runner.sh`; preflight passed, registration + svc install proceeded through to `active`.

### Architectural Changes

None — no Rule-4 stops triggered.

## Human-Action Checkpoints

### Task 3: Runner install on Talos host

- **Type:** checkpoint:human-action (blocking, unavoidable — requires sudo + authenticated `gh` CLI on the Talos host, neither automatable by the executor).
- **What was needed:** SSH/terminal as `btc` on 10.70.0.102, run `./scripts/install-runner.sh`, supply sudo password at `svc.sh install btc` prompt, confirm runner Idle on GitHub UI.
- **Outcome:** Success after one in-flight fix (scope check, above). Runner service `actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` confirmed `active` via systemctl; runner appears Idle on github.com/dan-xuereb/cos-docs Settings/Actions/Runners with labels `self-hosted,cos-docs,talos`; version 2.333.1.

## Files Created

- **`scripts/emit-site-manifest.sh`** (122 lines, `chmod +x`) — Bash script: accepts `--workspace PATH` (default `/home/btc/github`); resolves `cos_docs_sha` via `$GITHUB_SHA` → `git rev-parse HEAD` → `"unknown"`; iterates `"$WORKSPACE"/*/` skipping cos-docs and non-git dirs; builds JSON via `jq -Rn` from `name<TAB>sha` stream; stderr for logs, stdout for JSON. Verified output: 31 repos, 40-hex cos_docs_sha, ISO-8601 timestamp.
- **`scripts/install-runner.sh`** (170 lines, `chmod +x`) — Constants: `REPO=dan-xuereb/cos-docs`, `RUNNER_HOME=/home/btc/actions-runner`, `RUNNER_NAME=talos-cos-docs`, `RUNNER_LABELS=self-hosted,cos-docs,talos`. Flow: preconditions → GH release fetch → SHA256 verify → tar extract → `gh api … registration-token` → `config.sh --unattended --replace` → `sudo ./svc.sh install btc && start` → `systemctl is-active` post-gate.
- **`.planning/phases/04-deploy-ci/RUNNER-SETUP.md`** (220 lines) — Operator runbook: prerequisites (gh CLI, `gh auth status` with `repo` scope, jq/curl/tar, fresh `/home/btc/actions-runner/`), install steps (SSH as btc → `cd cos-docs` → `./scripts/install-runner.sh`), verification (`systemctl is-active` + GitHub UI), troubleshooting (scope missing, existing runner, service not active), uninstall flow.

## Verification Performed

| Check | Result |
|-------|--------|
| Task 1: `test -x scripts/emit-site-manifest.sh` | OK |
| Task 1: `./scripts/emit-site-manifest.sh \| jq -e .` | OK — valid JSON |
| Task 1: `.repos \| length >= 25` | OK — 31 repos |
| Task 1: `.repos \| has("cos-docs") \| not` | OK — cos-docs excluded |
| Task 1: `.cos_docs_sha \| test("^[0-9a-f]{40}$\|^unknown$")` | OK — 40-hex |
| Task 1: `.generated_at \| test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")` | OK |
| Task 2: `test -x scripts/install-runner.sh && bash -n …` | OK |
| Task 2: plan-contract greps (`dan-xuereb/cos-docs`, `registration-token`, scope check, service name) | OK |
| Task 2: `test -f RUNNER-SETUP.md` + plan-contract greps | OK |
| Task 3: `systemctl is-active actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` | **active** |
| Task 3: GitHub Settings/Actions/Runners shows `talos-cos-docs` Idle with correct labels | OK (confirmed by operator) |
| Task 3: Runner version | 2.333.1 |
| Task 3: runner work-dir isolation (`/home/btc/actions-runner/_work/` vs. `/home/btc/github/cos-docs/`) | OK — distinct paths |

## Requirement Closeout

This plan **does not** flip CI-01/02/03 to Complete in REQUIREMENTS.md. It delivers the runner + manifest-script infrastructure that those requirements depend on, but the actual satisfaction requires:

- **CI-01** (nightly schedule) — satisfied when the Plan 04-04 `.github/workflows/build.yml` runs on its cron trigger.
- **CI-02** (push-to-main + workflow_dispatch) — satisfied by the same Plan 04-04 workflow's `on:` triggers.
- **CI-03** (push to private registry) — satisfied when Plan 04-04's workflow pushes `10.70.0.30:5000/cos-docs:<tag>` from a successful run on this runner; final proof in Plan 04-05 E2E.

Requirements remain Pending; traceability table unchanged.

## Threat Flags

No new threat surfaces beyond the plan's `<threat_model>`. Runner tarball SHA256 verification (T-04-03-01 mitigation) applied during install. Registration-token flow (T-04-03-03 mitigation) proceeded over HTTPS via gh CLI; token never touched stdout.

## Decisions Made

- **Scope relaxation (detailed above in Deviations):** `repo` scope sufficient; `admin:repo_hook` dropped from the hard requirement. Codified in `install-runner.sh` preflight and reflected in `RUNNER-SETUP.md` prerequisites.
- **Runner installed as user `btc`** (plan choice accepted): required for build-all-api.sh cross-repo filesystem access on the shared workspace; matches workspace norms (T-04-03-02 disposition: accept).
- **Runner labels finalized as `self-hosted,cos-docs,talos`**: `self-hosted` is default (inherited); `cos-docs` enables workflow routing to this specific runner; `talos` encodes the host class for future multi-runner scenarios (e.g., if a second runner is added on a non-Talos host).

## Known Stubs

None. All authored artifacts are fully functional; no placeholder data flows to UI or output.

## Self-Check: PASSED

- `scripts/emit-site-manifest.sh` — FOUND (executable, 122 lines, produces valid JSON)
- `scripts/install-runner.sh` — FOUND (executable, 170 lines, includes Rule-2 scope fix)
- `.planning/phases/04-deploy-ci/RUNNER-SETUP.md` — FOUND (220 lines)
- Commit `acc1d7b` — FOUND in `git log --oneline` (Task 1)
- Commit `040926e` — FOUND in `git log --oneline` (Task 2)
- Commit `3c9daa9` — FOUND in `git log --oneline` (Task 2 in-flight Rule-2 fix)
- systemd unit `actions.runner.dan-xuereb-cos-docs.talos-cos-docs.service` — **active** on 10.70.0.102
- Runner visible at github.com/dan-xuereb/cos-docs Settings/Actions/Runners — confirmed by operator

---
*Plan 04-03 completed 2026-04-20. Next up: Plan 04-04 (`.github/workflows/build.yml` — nightly + push-to-main + workflow_dispatch triggers against this runner).*
