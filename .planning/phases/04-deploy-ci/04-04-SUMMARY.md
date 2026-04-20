---
phase: 04-deploy-ci
plan: 04
subsystem: ci
tags: [github-actions, workflow, self-hosted-runner, docker-push, nightly-cron, workflow-dispatch, insecure-registry]

requires:
  - phase: 04-deploy-ci
    provides: "Plan 04-01 Dockerfile (multi-stage nginx) — workflow `docker build .` consumes it and pushes to 10.70.0.30:5000/cos-docs; Plan 04-03 self-hosted runner (`talos-cos-docs`, labels self-hosted,cos-docs,talos) — workflow `runs-on: self-hosted` lands here; Plan 04-03 scripts/emit-site-manifest.sh — invoked by the `Pull sibling repos and emit manifest` step to generate site-manifest.json baked into the image."
provides:
  - ".github/workflows/build.yml — single-job, 9-step CI pipeline for cos-docs: in-place git sync (no actions/checkout), sibling pull loop, site-manifest emission, build-all-api --keep, mkdocs --strict, strict-fail gate with workflow_dispatch allow_partial override, always-on restore, failure artifact upload, multi-tag docker push (:<sha> + :latest + :nightly-YYYYMMDD on schedule), and deploy hint (D-06)."
  - "Verified-green workflow_dispatch run 24673734857 (1m44s, success) with registry tags :4934189 + :latest landed at 10.70.0.30:5000/cos-docs."
affects: [04-05 E2E deploy verification consumes the :latest tag pushed by this workflow; future nightly rebuilds will auto-refresh the site without operator action]

tech-stack:
  added:
    - "GitHub Actions workflow YAML (on: push/schedule/workflow_dispatch + concurrency + timeout-minutes)"
    - "actions/upload-artifact@v4 (for failure-mode diagnostic)"
  patterns:
    - "In-place workspace sync on self-hosted runner: `git fetch origin && git reset --hard \"$GITHUB_SHA\" && git clean -fdx -e site/ -e .venv-docs/ -e .venv-aggr/` instead of actions/checkout (RESEARCH §3 + Pitfall 1). Preserves sibling read access and persistent virtualenvs across runs."
    - "Concurrency group `cos-docs-build` with `cancel-in-progress: false` serializes nightly + push + dispatch runs so sibling docs/api.md swap/restore never races (T-04-04-02)."
    - "Strict-fail gate pattern: schedule + push defensively override the `allow_partial` string to false; only workflow_dispatch can opt in to partial-failure acceptance. Comparison uses `[ \"$ALLOW_PARTIAL\" = \"true\" ]` to handle the string-ification of the typed boolean input (RESEARCH Pitfall 12)."
    - "`if: always()` on the restore step is the correctness invariant — even on failure, sibling docs/api.md must be restored or the workspace stays dirty indefinitely (T-04-04-01)."

key-files:
  created:
    - ".github/workflows/build.yml"
  modified:
    - ".github/workflows/build.yml (in-flight Rule-2 fix — removed erroneous `mv site-manifest.json site/site-manifest.json`)"

key-decisions:
  - "site-manifest.json stays at cos-docs repo root and is NOT moved into site/ after mkdocs build. Root cause: the Dockerfile's runtime stage `COPY site-manifest.json /usr/share/nginx/html/site-manifest.json` reads from the repo root (the Docker build context); moving it into site/ before docker build caused `COPY failed: file not found in build context` (run 24673509302 red on this exact line). Dockerfile is the source of truth — the workflow emits the manifest at root and lets the Dockerfile COPY it into the image alongside site/."
  - "`:nightly-YYYYMMDD` tag only emits when `github.event_name == 'schedule'`. Operator-triggered workflow_dispatch runs produce `:<short-sha>` + `:latest` only, which matches D-03 (nightly tag denotes provenance of a scheduled run, not any manual rebuild)."
  - "`timeout-minutes: 45` cap on the job — generous headroom over the observed 1m44s green run, but tight enough that a hung sibling git pull or pip install will kill the runner before it blocks the next nightly slot."

patterns-established:
  - "GHA self-hosted runner + workspace-outside-runner pattern: the runner's _work/ directory is NOT the cos-docs repo; the workflow `defaults.run.working-directory: /home/btc/github/cos-docs` plus `git reset --hard \"$GITHUB_SHA\"` ties the in-place clone to the exact commit GitHub dispatched. Reusable for any future workflow on the talos-cos-docs runner that needs to read sibling workspaces."
  - "Iterative workflow verification via two dispatches: first run (24673509302) red at step 8 `COPY site-manifest.json` → operator fixed the `mv` line on main → second run (24673734857) green end-to-end. The fix-commit-dispatch loop is the intended feedback cycle for workflow bugs; actionlint + YAML parse + grep checks catch syntactic problems but not semantic mismatches between the workflow and the Dockerfile COPY layout."

requirements-completed: [CI-01, CI-02, CI-03, DEPLOY-01]

duration: ~35min (workflow author + push + first dispatch red + fix + second dispatch green)
completed: 2026-04-20
---

# Phase 04 Plan 04: GitHub Actions Build-and-Push Workflow Summary

**Self-hosted `.github/workflows/build.yml` drives nightly + push + dispatch rebuilds of the cos-docs aggregator image to 10.70.0.30:5000/cos-docs, verified green end-to-end by workflow_dispatch run 24673734857 (1m44s, tags :4934189 + :latest landed).**

## Performance

- **Duration:** ~35 min (author + two-dispatch verify cycle)
- **Started:** 2026-04-20 (workflow author)
- **Completed:** 2026-04-20 (green run 24673734857)
- **Tasks:** 2 (Task 1 auto; Task 2 checkpoint:human-verify)
- **Files modified:** 1 created + 1 in-flight edit (same file)

## Accomplishments

- CI-01 satisfied: nightly `cron: '0 7 * * *'` declared and parsed by GitHub (`gh workflow list` shows "Build and push docs image").
- CI-02 satisfied: `push: { branches: [main] }` + `workflow_dispatch` with `allow_partial` boolean input declared; dispatch exercised live on run 24673734857.
- CI-03 satisfied: successful run pushed `10.70.0.30:5000/cos-docs:4934189` + `10.70.0.30:5000/cos-docs:latest` to the private registry; `curl http://10.70.0.30:5000/v2/cos-docs/tags/list | jq .tags` returns `["4934189","latest"]`.
- DEPLOY-01 fully verified: Plan 04-01's Dockerfile builds green in CI against real runner state (not just local smoke), proving the multi-stage build works against the post-pre-render site/ tree.
- Strict-fail gate, always-on restore, failure artifact upload, and deploy-hint lines all observed in green run log.

## Task Commits

1. **Task 1: Author .github/workflows/build.yml** — `cab97f6` (`ci(04-04): add build-and-push workflow (self-hosted, nightly + push + dispatch)`)
2. **In-flight Rule-2 fix: drop erroneous `mv site-manifest.json site/` line** — `4934189` (`fix(04-04): keep site-manifest.json at repo root for Dockerfile COPY`)
3. **Task 2: Operator-triggered verification** — workflow_dispatch run 24673734857 green; no commit required (verification-only checkpoint).

**Plan metadata commit:** pending (this SUMMARY + STATE/ROADMAP/REQUIREMENTS updates, committed as a single `docs(04-04):` commit after SUMMARY write).

## Files Created/Modified

- `.github/workflows/build.yml` — 154 lines; single `build` job on `runs-on: self-hosted` with 9 steps (sync / pull siblings + manifest / build-all-api --keep / mkdocs --strict / strict-fail gate / restore always / upload-artifact on failure / docker build + multi-tag push / deploy hint). Concurrency group `cos-docs-build`, timeout 45m, `defaults.run.working-directory: /home/btc/github/cos-docs`. NO `actions/checkout` (in-place git sync per RESEARCH §3).

## Decisions Made

- **site-manifest.json location:** root of build context, not inside `site/`. The Dockerfile `COPY site-manifest.json /usr/share/nginx/html/site-manifest.json` is the source of truth; workflow emits manifest at `/home/btc/github/cos-docs/site-manifest.json` and lets Docker pick it up from there. Pre-move into `site/` (initial authoring mistake) caused `COPY failed: not found in build context` on first dispatch.
- **`:nightly-YYYYMMDD` emission guarded by `github.event_name == 'schedule'`** — matches D-03 semantic (nightly tag = scheduled provenance, not "any recent build"). Confirmed on green dispatch run: no nightly tag was pushed, only `:4934189` + `:latest`, which is the correct behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical / Rule 1 - Bug] Removed `mv site-manifest.json site/site-manifest.json` after mkdocs build**
- **Found during:** Task 2 (first workflow_dispatch run 24673509302 failed on Docker build step)
- **Issue:** Workflow moved `site-manifest.json` into `site/` after the aggregator build, but the Dockerfile `COPY site-manifest.json /usr/share/nginx/html/site-manifest.json` reads from the build context root. Result: Docker build step failed with `COPY failed: file not found in build context` on run 24673509302.
- **Fix:** Deleted the `mv site-manifest.json site/site-manifest.json` line from the "Build aggregator site" step. Manifest now stays at repo root where Dockerfile expects it.
- **Files modified:** `.github/workflows/build.yml`
- **Verification:** Second dispatch run 24673734857 completed green in 1m44s; `curl http://10.70.0.30:5000/v2/cos-docs/tags/list` returns `["4934189","latest"]`.
- **Committed in:** `4934189` (`fix(04-04): keep site-manifest.json at repo root for Dockerfile COPY`)

---

**Total deviations:** 1 auto-fixed (1 bug / missing-critical — workflow-to-Dockerfile contract mismatch)
**Impact on plan:** In-scope correctness fix. No scope creep. Caught by the checkpoint:human-verify gate exactly as designed.

## Issues Encountered

- First dispatch (run 24673509302) failed red on the Docker build step due to the `mv` contract mismatch above. Resolved by committing 4934189 and re-dispatching; second run (24673734857) green end-to-end.
- `nightly-YYYYMMDD` tag deliberately not emitted on push-triggered runs — this is correct per D-03, not a bug. Future scheduled-run verification (next 07:00 UTC tick or manual `workflow_dispatch` with the event type spoofed) can confirm the nightly-tag branch path, but is not required for plan completion.

## User Setup Required

None — workflow uses the self-hosted runner installed in Plan 04-03 with no additional secrets. Registry push is anonymous over plaintext HTTP on the internal VLAN (threat model: accepted for 10.70.0.30 insecure registry).

## Next Phase Readiness

- **04-05 (E2E deploy verification) unblocked:** `:latest` tag is now being pushed by CI on every green build; `kubectl apply -k cos-docs/k8s/` will pull the current image from `10.70.0.30:5000/cos-docs:latest` and the 04-05 curl assertions at `http://10.70.0.102:30083/` can run against a known-fresh site.
- **Phase 4 progress:** 4/5 plans complete; only DEPLOY-04 verification remains.
- **Plan 02-03 (per-repo content authoring)** remains independently pending under Phase 2.

## Self-Check: PASSED

- `.github/workflows/build.yml` FOUND on main (cab97f6 initial + 4934189 fix).
- Commit `cab97f6` FOUND in git log.
- Commit `4934189` FOUND in git log (HEAD of main).
- Registry tags verified: `curl -fsS http://10.70.0.30:5000/v2/cos-docs/tags/list` → `{"name":"cos-docs","tags":["4934189","latest"]}` ✓.
- GH run 24673734857 conclusion: success (1m44s, operator-observed).

---
*Phase: 04-deploy-ci*
*Completed: 2026-04-20*
