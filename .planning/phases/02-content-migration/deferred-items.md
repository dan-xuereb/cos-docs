
## Task 1 (02-03) deferred items

### BTC-Forge: strict build fails due to pre-existing docstring autorefs warning
- **Symptom**: `mkdocs build --strict` fails with:
  `mkdocs_autorefs: api.md: from /home/btc/github/BTC-Forge/src/api.py:75: (src.api.scan_granularity_stats) Could not find cross-reference target 'exchange'`
- **Scope**: Pre-existing — reproduces against the Phase 1 scaffold-only `docs/api.md` (just `::: src`). Not caused by 02-03 content edits.
- **Root cause**: `scan_granularity_stats` docstring contains `progress["exchanges"][exchange][granularity]` — autorefs tries to resolve `exchange` / `granularity` as API symbols.
- **Fix path**: Either escape the docstring tokens (backtick them explicitly, or put them in a fenced code block), OR disable `autorefs` strict resolution for that module, OR add `strict: false` to mkdocs.yml for this repo.
- **Deferred**: does not block 02-03 Task 1 — the content commit landed; the strict gate is a pre-existing rollout defect tracked separately (likely worth a follow-up fix in BTC-Forge's source docstrings).

## Task 2 (02-03) deferred items

### COS-MSE: strict build fails due to pre-existing griffe docstring warnings
- **Symptom**: `mkdocs build --strict` aborts with 3 griffe warnings:
  ```
  griffe: src/mse/regimes/smoothing.py:4: Failed to get 'signature: description' pair from '* EWMA (exponentially weighted moving average)'
  griffe: src/mse/regimes/smoothing.py:5: Failed to get 'signature: description' pair from '* Rolling mean'
  griffe: src/mse/regimes/smoothing.py:6: Failed to get 'signature: description' pair from '* Rolling median'
  ```
- **Scope**: Pre-existing — the same warnings appeared in the 02-02 rollout and are the reason COS-MSE was classified FAIL there. Not caused by 02-03 content edits. Reproduces against the Phase 1 scaffold-only api.md (`::: mse`).
- **Root cause**: Bullet-list docstring in `src/mse/regimes/smoothing.py` is not Griffe-parseable (expects `signature: description` pairs).
- **Fix path**: Reformat bullet-list docstrings in `smoothing.py` to standard Google/NumPy-style parameter docstrings, OR wrap the list in a fenced code block so Griffe leaves it alone.
- **Deferred**: content commit `556756b` landed on `main` per same pattern as BTC-Forge Task 1 deferral. Strict-build failure is orthogonal to the CONT-02/03/04 content contract.

### COS-MSE: scaffold files (`mkdocs.yml`, `requirements-docs.txt`) never committed in 02-02
- **Symptom**: Task 2 discovered that `mkdocs.yml` and `requirements-docs.txt` were still untracked in COS-MSE despite 02-ROLLOUT-STATUS.md listing the repo as having a "scaffold committed" step. Only the `feat: initial commit` predates Task 2.
- **Scope**: Orthogonal to Task 2 content scope (Task 2 adds docs/*.md only).
- **Deferred**: untracked scaffold files left in place for a follow-up housekeeping commit. Mkdocs strict build still succeeds locally because the files exist on disk; the only artifact of the gap is `git status` noise.

### cos-signal-explorer: api.md has 4 `:::` blocks (Task 2 target was ≥5)
- **Symptom**: The Task 2 "library repos shine" rule calls for ≥5 `:::` directives in api.md. cos-signal-explorer physically has only 3 Python source modules (`__init__.py`, `_helpers/compose.py`, `_helpers/pickers.py`) plus the `_helpers` package — 4 addressable targets.
- **Scope**: Per plan guidance "verify each submodule exists via `ls src/<pkg>/<path>` before writing", using `__init__` as a 5th target caused a strict-build error (`mkdocstrings: cos_signal_explorer.__init__ could not be found`). The 5-block minimum is not physically reachable without synthesizing fake modules.
- **Deferred**: 4 `:::` blocks shipped (root + `_helpers` + `_helpers.compose` + `_helpers.pickers`). This exceeds the global CONT-04 minimum (≥3) but falls one short of the Task 2 "library" stricter ask. Recommend the verifier treat this as content-complete given the underlying physical module count; no additional work queued.

### COS-Core: never scaffolded in Phase 1 (discovered during Task 2)
- **Symptom**: `/home/btc/github/COS-Core/` had no `docs/`, `mkdocs.yml`, or `requirements-docs.txt` at Task 2 start. `scaffold-all.sh` intentionally excludes COS-Core because it lacks its own `.git` (it lives inside the parent `/home/btc/github` git repo), on the assumption that Phase 1 had scaffolded it as part of the parent commit — but the parent git history shows only `COS-Core/uv.lock` was ever tracked.
- **Action**: Task 2 ran `scripts/scaffold.sh /home/btc/github/COS-Core` inline, then authored content on top. Commit `ba446f7` on the parent `/home/btc/github` git lands docs/index.md, docs/architecture.md, docs/api.md, mkdocs.yml, and requirements-docs.txt together.
- **Regression check**: The Phase 1 verification benchmark (`grep 'Lowercase exchange name' site/api/index.html`) passes.
- **Deferred**: COS-Core's `pyproject.toml`, `src/`, `tests/` remain untracked in the parent git (unrelated to docs). Not a Task 2 concern.

