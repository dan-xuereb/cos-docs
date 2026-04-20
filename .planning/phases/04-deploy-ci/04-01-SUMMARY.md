---
phase: 04-deploy-ci
plan: 01
subsystem: infra
tags: [docker, nginx, dockerfile, multi-stage, build-context, mkdocs, static-site, kubernetes-ready]

# Dependency graph
requires:
  - phase: 03-aggregator-api-strategy
    provides: "site/ produced by build-all-api.sh --keep + mkdocs build --strict + --restore pipeline (Plan 03-02/03-03)"
provides:
  - "cos-docs/Dockerfile: multi-stage (AS runtime) image that COPYs pre-built site/ into nginx:1.27-alpine"
  - "cos-docs/deploy/nginx.conf: static serving with try_files for use_directory_urls, /health probe endpoint, gzip, themed 404 passthrough"
  - "cos-docs/.dockerignore: bounds build context to site/ + site-manifest.json + Dockerfile + deploy/ (excludes .planning, .venv*, docs/, scripts/, mkdocs.yml, .git)"
  - "cos-docs/.gitignore: blocks site/, site-manifest.json, and local aggregator venvs from entering git history"
affects: [04-02-k8s-manifests, 04-03-ci-workflow, 04-04-manifest-emit]

# Tech tracking
tech-stack:
  added:
    - "nginx:1.27-alpine (base image, pinned minor)"
  patterns:
    - "Multi-stage label (FROM ... AS runtime) retained for workspace convention even when there is no separate build stage (site/ is built outside Docker)"
    - "Non-root container via USER 101 with chown of /var/cache/nginx, /var/log/nginx, /var/run/nginx.pid to mirror quant-dashboard/Dockerfile"
    - ".dockerignore-as-gate: the ONLY barrier keeping 29-sibling workspace tree out of build context (RESEARCH §4 Pitfall 2)"

key-files:
  created:
    - "cos-docs/Dockerfile"
    - "cos-docs/deploy/nginx.conf"
    - "cos-docs/.dockerignore"
    - "cos-docs/.gitignore"
  modified: []

key-decisions:
  - "Multi-stage label kept (FROM nginx:1.27-alpine AS runtime) even though there is no separate builder stage — preserves workspace convention and leaves door open if a future stage needs to generate a redirect map or asset transform."
  - "site/ and site-manifest.json are Docker build inputs only, never committed to git — added first cos-docs/.gitignore to enforce this (previously no .gitignore existed)."
  - "Omit text/html from gzip_types: nginx base config already includes it and duplicating it emits a startup warning. Observed via docker nginx -t; fixed pre-commit."
  - "Early --restore trap in the smoke script: --keep swap-in is run, then restore runs before docker build, guaranteeing siblings are clean even if later steps abort."

patterns-established:
  - "Dockerfile-header doc contract: explicitly document that site/ is built outside Docker and why (prevents future maintainers from regressing into a giant build context)"
  - "Non-root-nginx pattern: listen 8080 + USER 101 + chown of writable paths — reusable for any future static-serving pod in the workspace"

requirements-completed: [DEPLOY-01, DEPLOY-04]

# Metrics
duration: 4m 20s
completed: 2026-04-20
---

# Phase 4 Plan 01: Runtime Container Surface Summary

**Multi-stage `nginx:1.27-alpine` Dockerfile that COPYs a pre-built mkdocs `site/` + a scoped `.dockerignore` + a directory-URL-aware `nginx.conf` with `/health`; all three verified by a local end-to-end smoke (build-all-api → mkdocs build --strict → docker build → docker run → four curl assertions).**

## Performance

- **Duration:** ~4m 20s
- **Started:** 2026-04-20T12:33:09Z
- **Completed:** 2026-04-20T12:37:29Z
- **Tasks:** 3 / 3
- **Files created:** 4 (Dockerfile, deploy/nginx.conf, .dockerignore, .gitignore)

## Accomplishments

- DEPLOY-01 satisfied: `docker build -t cos-docs:test .` succeeds in 3.4s, producing a 111MB image with a 31.48MB build context (vs. the multi-GB context that would transfer without `.dockerignore`).
- DEPLOY-04 static-serving half satisfied: `curl http://127.0.0.1:8081/` returns HTTP 200 with the Xuer Capital landing page; `/architecture/` returns HTTP 200 with the workspace Mermaid page (proves `use_directory_urls=True` directory-URL serving via `try_files`); `/site-manifest.json` returns HTTP 200 verbatim; `/health` returns HTTP 200 `healthy\n` for k8s probes.
- Non-root runtime verified: image runs as UID 101 with nginx bound to 8080, matching the security posture established by `quant-dashboard`.
- Build context bounded: `.dockerignore` excludes `.planning/`, `.venv*`, `docs/`, `scripts/`, `mkdocs.yml`, `.git`, `tests/`, `__pycache__`, `*.pyc/.pyo` — confirmed by the 31.48MB context figure reported by `docker build` (site/ dominates at ~30MB; the rest is Dockerfile + nginx.conf + stub manifest).

## Task Commits

1. **Task 1: Write `.dockerignore`** — `9f274b1` (chore)
2. **Task 2: Write `deploy/nginx.conf`** — `1efc7ad` (feat) — includes the Rule 1 auto-fix that removed `text/html` from `gzip_types` to silence the nginx duplicate-MIME warning.
3. **Task 3: Write `Dockerfile` + local smoke test** — `0cef9d6` (feat) — ships Dockerfile and the companion `.gitignore` that blocks `site/` / `site-manifest.json` / aggregator venvs.

## Files Created/Modified

- `cos-docs/.dockerignore` — 20 lines; keeps Docker build context minimal (site/ + site-manifest.json + Dockerfile + deploy/).
- `cos-docs/deploy/nginx.conf` — 48 lines; `listen 8080`, `try_files $uri $uri/ $uri/index.html /404.html`, `location = /health { return 200 "healthy\n"; }`, gzip for css/js/svg/json/xml, themed 404 passthrough.
- `cos-docs/Dockerfile` — 43 lines; single-stage `FROM nginx:1.27-alpine AS runtime`, COPY site/ + site-manifest.json + deploy/nginx.conf, non-root UID 101, HEALTHCHECK wget `/health`.
- `cos-docs/.gitignore` — 17 lines (first .gitignore in repo); blocks site/, site-manifest.json, .venv-aggr-local/, .venv-agg/, __pycache__/, *.pyc/.pyo, .build-all-api-status.md (though that last one is already tracked in git — ignore only affects future clones).

## Decisions Made

See `key-decisions` in frontmatter. Summary: multi-stage label preserved, site/ build stays outside Docker, text/html gzip entry removed for warning-free startup, cos-docs's first `.gitignore` introduced to lock down build outputs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] nginx "duplicate MIME type text/html" warning on config test**

- **Found during:** Task 2 (nginx.conf syntax check via `docker run nginx:1.27-alpine nginx -t`)
- **Issue:** The verbatim gzip_types list copied from RESEARCH §5 included `text/html`, which the nginx base config already includes. Both `nginx -t` and a running container would emit `[warn] duplicate MIME type "text/html" in /etc/nginx/conf.d/default.conf:31`. Noisy logs for no benefit; prevents a clean startup bar in k8s.
- **Fix:** Removed the `text/html` line from gzip_types. HTML compression is still active (nginx default); behavior unchanged.
- **Files modified:** `cos-docs/deploy/nginx.conf`
- **Verification:** Re-ran `docker run --rm nginx:1.27-alpine nginx -t` — output is now `syntax is ok` + `test is successful` with no warnings.
- **Committed in:** `1efc7ad` (Task 2 commit)

**2. [Rule 2 - Missing Critical] No `.gitignore` existed in cos-docs; smoke-test artifacts (`site/`, `site-manifest.json`) risked accidental commit**

- **Found during:** Task 3 (pre-smoke audit)
- **Issue:** The repo had no `.gitignore`. `site/` and `site-manifest.json` are legitimate build outputs created during the local smoke test; without a gitignore, a future `git add .` could ingest a ~30MB site tree and mutate history silently. Plan language told us not to commit them, but lacked a structural enforcement.
- **Fix:** Authored `cos-docs/.gitignore` with `site/`, `site-manifest.json`, `.venv-aggr-local/`, `.venv-agg/`, `__pycache__/`, `*.pyc/.pyo`, `.build-all-api-status.md`.
- **Files modified:** `cos-docs/.gitignore` (new file)
- **Verification:** `git check-ignore -v site/ site-manifest.json .venv-aggr-local/` confirms all three are ignored by the respective rule lines. After smoke-test cleanup, `git status --short` shows neither site/ nor site-manifest.json.
- **Committed in:** `0cef9d6` (Task 3 commit, bundled with Dockerfile)

**3. [Rule 3 - Blocking] Smoke-script wrapper needed to guarantee `--restore` even on aborted build**

- **Found during:** Task 3 planning — the phase_context note warned that a mid-pipeline failure between `--keep` and the manual `--restore` would leave 20 sibling repos with swapped-in `docs/api.md` stubs.
- **Issue:** Plan's smoke test lists the commands linearly; if `mkdocs build --strict` or `docker build` failed, `./scripts/build-all-api.sh --restore` would never run, leaving siblings dirty for the next developer.
- **Fix:** Wrapped smoke steps in `set +e; trap restore EXIT` so `--restore` fires regardless of exit path. Also added `RESTORED=0` flag and an early `--restore` call before `docker build` (docker doesn't need swapped-in state; only the mkdocs build does).
- **Files modified:** Only the shell script invocation (no committed artifact changed by this deviation).
- **Verification:** Siblings are clean at the end of the smoke run (`git status` in `/home/btc/github/*` would show no tracked docs/api.md mutations; the build-all-api.sh summary printed "Restored originals for all 20 repos").
- **Committed in:** n/a (runtime-only guard; documented here for future re-runs).

---

**Total deviations:** 3 auto-fixed (1 Rule 1 bug, 1 Rule 2 missing critical, 1 Rule 3 blocking guard).
**Impact on plan:** All three improve durability of the artifacts / smoke procedure. No scope creep; no architectural changes.

## Issues Encountered

- None. The smoke pipeline ran cleanly on first full attempt after the two pre-commit deviations (text/html warning fix, gitignore addition).
- Informational MkDocs notes about `<repo>/` and `<repo>/architecture/` relative links resolving to INFO rather than WARNING are identical to those observed during Plan 03-03 — not introduced by this plan, not blocking `--strict`.

## User Setup Required

None — all artifacts are committed to `main` and exercised locally via Docker without needing any external credentials. Registry push / k8s apply are explicitly deferred to Plans 04-02 (manifests) and 04-03 (CI workflow).

## Next Phase Readiness

- **Plan 04-02 (Kustomize manifests on `kubernetes` branch):** unblocked. The Dockerfile's `containerPort` must match `deployment.yaml`'s — both should point at 8080. Nginx listens on 8080; deploy manifest should use `containerPort: 8080` + service `targetPort: 8080` + `nodePort: 30081` per CONTEXT D-05.
- **Plan 04-03 (CI workflow):** unblocked. Workflow will orchestrate the same sequence proven locally here (build-all-api.sh --keep + mkdocs build --strict + --restore + emit site-manifest.json + docker build + docker push). Recommend the workflow use the same early-restore + trap pattern employed in this plan's smoke test to keep sibling repos clean on abort.
- **Plan 04-04 (site-manifest.json emission):** stub already served at `/site-manifest.json` today (via `COPY site-manifest.json ./`). 04-04 provides the real generator; no Dockerfile change needed at that time.
- **Known non-blocker:** `.build-all-api-status.md` is tracked in git (from a prior phase commit) so the new `.gitignore` entry is ineffective for it. Out of scope for this plan; if future work wants it ignored, it needs `git rm --cached` first.

## Self-Check: PASSED

- `cos-docs/Dockerfile` — FOUND
- `cos-docs/deploy/nginx.conf` — FOUND
- `cos-docs/.dockerignore` — FOUND
- `cos-docs/.gitignore` — FOUND
- Commit `9f274b1` — FOUND
- Commit `1efc7ad` — FOUND
- Commit `0cef9d6` — FOUND
- All required directives verified via grep (FROM nginx:1.27-alpine, USER 101, EXPOSE 8080, HEALTHCHECK, try_files, listen 8080, location = /health, .planning, docs/, scripts/).
- Smoke test: `docker build` exit 0 with 31.48MB context; 4/4 curl assertions returned HTTP 200 with expected substrings.

---
*Phase: 04-deploy-ci*
*Plan: 01*
*Completed: 2026-04-20*
