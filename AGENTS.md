# Repository instructions

recoverome is an experimental R package. The development version implements
`setup_recovery()` for named analysis registration and `validate_recovery()`
for structural and historical-scope diagnostics. The other five functions in
the planned API are not implemented yet.

The next release target is the experimental GitHub MVP, version 0.2.0, with
the seven functions in `dev/architecture.md`. Bioconductor preparation is a
later milestone. Do not expand the statistical scope while implementing the
development workflow.

Only the maintainer decides and publishes releases. Do not release at
intermediate milestones. A future Bioconductor preparation phase targets
0.99.0; it is not the current version or an accepted Bioconductor release.

## Issue and review workflow

- Read `dev/development-workflow.md` before starting issue work.
- Use the `recoverome Development` project states: `Backlog`, `Ready`,
  `In progress`, `Review`, and `Done`. These are project fields, not labels.
- The project is https://github.com/users/xec-cm/projects/10. Native auto-add
  covers issues only: keep one card per issue and link its PR. Dependabot PRs
  remain in the normal PR list. The maintainer reviews native priorities and
  the Ready queue weekly; use the P0–P3 meanings in the workflow document.
- Keep at most two issues in `In progress` and `Review` combined. Draft PRs
  count toward this limit once work starts; do not start a third issue while
  an earlier one waits for review.
- Start implementation only from `Ready`: scope and acceptance criteria must
  be clear, blocking dependencies resolved, and any required short design RFC
  accepted through its document PR merged into `devel` by the maintainer.
  A comment, label, or closed RFC issue without that merge is insufficient.
- Assignment prepares the issue branch `codex/issue-N` and a draft PR against
  `devel`. Reuse that branch and PR rather than creating duplicates.
- If the branch exists but PR creation failed, reassignment will not repair
  it. Check for an existing PR and create one missing draft PR against `devel`
  with `Closes #N`, reusing the branch without deleting or recreating it.
- Assignment does not launch an agent. Agent sessions require an explicit
  user instruction or an already authorized task covering that work.
- Work in an isolated worktree on the assigned branch. Preserve existing
  branch commits and user changes; do not reset or force-push them.
- Obtain technical review from an independent agent before maintainer review.
  Record the reviewer/session, reviewed commit, scope, checks, and findings in
  the PR. Keep the issue `In progress` until review is complete and findings
  are resolved, with no required change left open.
  Then move it to `Review`. Refresh review after material changes.
- The maintainer reviews methodological decisions and performs every squash
  merge. Agents must never merge PRs or enable auto-merge.
- Include `Closes #N` so the maintainer merge closes the issue and native
  project automation sets `Done`. Verify that result; moving to `Done` alone
  never closes the issue. RFC document PRs follow the same completion path.
- Required checks are `R package checks`, `quality`, and
  `Build the documentation site`; the branch must be up to date with `devel`.
  Passing CI is not a substitute for independent or maintainer review.
- If GitHub visibly requests `Approve workflows to run` for a PR created or
  updated with `GITHUB_TOKEN`, report that exact action to the maintainer.
  Do not change credentials or authentication to bypass the waiting state.

## Scope and changes

- Read `dev/architecture.md` before changing data contracts or public APIs.
- Preserve user changes and unrelated work. Keep edits focused on the task.
- Do not add analytical stubs, placeholder return values, or fabricated
  benchmark results. Implement useful behavior before exporting it.
- Keep planned and implemented functionality clearly separated in docs.
- Do not add runtime libraries until implemented code uses them.
- Do not make Git commits, create branches, or publish changes unless the task
  authorizes those actions. Existing user authorization persists; do not ask
  again for routine steps already covered by the active task. Merge authority
  remains with the maintainer.

## R implementation

- Read and follow [the R style guide](dev/r-style.md) before editing R code.
  It records the maintainer's style from historical dar code and distinguishes
  it from deliberate recoverome improvements. Use snake_case, two-space indents,
  one argument per line for long signatures/calls, and visibly separated stages.
  Keep helpers purposeful and dependencies explicit; do not imitate historical
  slot access, implicit coercion or error-handling problems.
- Use `cli::cli_abort()` through `.recovery_abort()` for recoverome errors.
  Write glue-style templates with semantic markup and interpolate values;
  do not assemble templates from user data. Keep the interpolation environment
  local to the failing check and preserve the public call through helpers.
  Use `cli::cli_warn()` / `cli::cli_inform()` only when behavior warrants a
  warning or message; successful registration should remain quiet.
- Validate raw inputs once at the public boundary. Internal helpers should
  trust already normalized types and check only their own relationships.
  Delegate container structure to TSE/S4 validity; retain recoverome-specific
  identity, membership, time and namespace checks that TSE cannot guarantee.
- Use `Rscript --vanilla` for reproducible command-line execution.
- Use public accessors for TSE, SummarizedExperiment, and S4Vectors objects.
  Do not read or write S4 slots directly.
- The planned setup/add functions accept and return a TSE. Preserve unrelated
  assays, identities, and user metadata.
- Keep analysis records in named metadata analyses and sample annotations in
  `colData()` columns prefixed with `rec_<analysis>_`.
- Preserve original analysis scope after filtering. Never silently refit,
  rebuild a reference, or recompute a historical outcome.
- Validate identities and dependencies explicitly. Do not rely on positional
  matching or implicit recycling.

## Documentation and checks

- Write project documentation in English and use readable line lengths.
- Edit `README.Rmd`; regenerate `README.md` rather than editing it directly.
- Mark proposed API examples with `eval=FALSE`. Executed vignette chunks must
  use available functions and make no unsupported analytical claims.
- Use meaningful tests for implemented behavior and failure modes. Do not add
  tests that merely encode placeholder outputs.
- Reuse the bundled synthetic `recovery_examples` for tests and runnable examples.
  Edit `data-raw/recovery_examples.R` and regenerate the data file when changing
  a shared case. Keep expected test values independently stated; deriving them
  from the function under test or its stored result cannot verify correctness.
- For numerical code, include small deterministic R examples with independently
  checkable expected values and justified tolerances. Use coverage to find
  untested behavior, without an arbitrary percentage target.
- Update documentation and `NEWS.md` for user-visible behavior changes. Explain
  in the PR when an internal change needs no NEWS entry or additional tests.
- Justify each new dependency and add it only when implemented code uses it.
- Regenerate documentation with the roxygen2 version pinned in `DESCRIPTION`
  (`Config/Needs/quality` and `Config/roxygen2/version`). Change a pin only as an
  intentional tooling change with regenerated output checked in the same PR.
- Run checks appropriate to the change and report their actual outcomes. Run
  the package check before the Bioconductor check, which uses its built
  package artifact:

```sh
Rscript --vanilla dev/check-package.R
Rscript --vanilla dev/check-generated.R
Rscript --vanilla dev/check-bioc.R
```

The Bioconductor check is informative at this stage. Its presence does not
mean the package has been submitted to or accepted by Bioconductor. Resolve or
report relevant findings; never claim that an unrun check passed.
