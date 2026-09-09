# Contributing to recoverome

Thank you for contributing. The experimental development version provides
`setup_recovery()` for registration and `validate_recovery()` for registration
diagnostics; the remaining five functions
are planned. Contributions should make a concrete, reviewable improvement
and distinguish implemented behavior from proposals.

The next target is an experimental **0.2.0 GitHub MVP** covering the seven
functions in the architecture contract. Bioconductor preparation comes later.
Implementation work is tracked in the public
[recoverome Development project](https://github.com/users/xec-cm/projects/10)
and the [issue backlog](https://github.com/xec-cm/recoverome/issues).

## Before changing the interface

Read [the architecture contract](https://github.com/xec-cm/recoverome/blob/devel/dev/architecture.md)
and the repository's
`AGENTS.md`. Discuss substantial API or statistical changes in an issue before
investing in an implementation. State the intended user question, estimand,
input requirements, and limitations.

The development branch is `devel`. The
[development workflow](https://github.com/xec-cm/recoverome/blob/devel/dev/development-workflow.md)
defines issue readiness, branch ownership, review, and release expectations.
Keep changes focused and preserve unrelated work. New runtime dependencies
must support an implemented feature and include a justification in the PR.

## From an issue to a pull request

Work moves through `Backlog` → `Ready` → `In progress` → `Review` → `Done`.
No more than **two issues combined** may be in `In progress` or `Review`.
Finish or unblock active work before starting another item.

The project's native auto-add tracks issues only, with one card per issue.
Link PRs from their issues; keep Dependabot PRs in the normal PR list. The
maintainer reviews priorities and the `Ready` queue weekly. Use native
priorities `P0` for urgent blockers, `P1` for the release's critical path,
`P2` for other planned work, and `P3` for lower-priority or later work.

An implementation issue becomes `Ready` only when its scope and acceptance
criteria are clear, blocking dependencies are resolved, and each necessary
design RFC has been merged into `devel` by the maintainer. Every RFC produces
a short design document and follows the same reviewed PR workflow. A feature
request, agreement in a comment, or closing the RFC issue without its merged
document does not constitute design acceptance.

Assigning an issue prepares `codex/issue-N` and a draft PR against `devel`.
Reuse those resources. An agent still needs an explicitly authorized session;
assignment does not launch one. The agent should work in an isolated worktree
on that branch, preserving previous commits and user changes.

If assignment creates the branch but fails before opening its PR, reassignment
will not repair it: the automation stops when the branch exists. Check for an
existing PR, then reuse the branch to create a single draft PR against `devel`
with `Closes #N` in its description. Do not delete or recreate the branch.

Keep the draft PR updated with its scope, issue/RFC links, progress, and check
results. Before requesting maintainer review, obtain and record an independent
agent's technical review of the current changes. Keep the issue `In progress`
while that review and its fixes are underway. A review record must identify
the reviewer/session and commit, checks or inspection performed, findings,
and how findings were resolved. Once no required
change remains open, move the issue to `Review` and make the PR ready for
maintainer review. A self-review or a CI result does not satisfy this
requirement.

The maintainer reviews the methodological decisions and **squash-merges every
PR**. Agents never merge and must not enable auto-merge. Required checks are
`R package checks`, `quality`, and `Build the documentation site`; branches
must be up to date with `devel`. The technical review record does not require
a second GitHub account or a formal approval from an agent account.

Keep `Closes #N` in the PR description. The maintainer's merge closes the issue,
and native project automation moves the closed issue to `Done`. Verify that
result after merge. Moving a project card to `Done` alone never closes its
issue. RFC document PRs follow the same completion path.

GitHub may show `Approve workflows to run` on PRs created or updated with
`GITHUB_TOKEN`. When that state is visible, tell the maintainer which workflow
is waiting. Keep the existing authentication configuration; do not replace
tokens or trigger unrelated writes to bypass the approval state.

## Local development checks

Run checks from the repository root with a clean R session in the order shown.
The package check must run before the Bioconductor check because the latter
uses the package artifact built by the former:

```sh
Rscript --vanilla dev/check-package.R
Rscript --vanilla dev/check-generated.R
Rscript --vanilla dev/check-bioc.R
```

The Bioconductor check is informative during this early development stage;
it does not imply that the package is submitted to or accepted by
Bioconductor. Review its findings and report relevant limitations in a pull
request. Do not describe checks that were not run as passing.

Edit `README.Rmd`, not the generated `README.md`. Keep generated documentation
in sync using the project's generation workflow and verify it with
`dev/check-generated.R`. Use the roxygen2 version pinned in
`Config/Needs/quality` and `Config/roxygen2/version` in `DESCRIPTION` when
regenerating documentation so local output matches CI. A pin update is an
intentional tooling change and must include the resulting generated files.

## Code and documentation

- Use TSE and SummarizedExperiment accessors rather than direct S4 slot access.
- Preserve unrelated assays and user metadata.
- Keep named analyses separate and make result provenance explicit.
- Preserve the original scope of historical analyses after filtering; never
  silently refit or reclassify them.
- Add meaningful tests for implemented contracts and failure modes. Do not
  add analytical stubs or tests that merely assert placeholder values.
- For numerical code, provide small deterministic R examples with independently
  checkable expected values and explicit tolerances where needed. Use coverage
  reports to find untested behavior, without an arbitrary percentage target.
- Mark proposed API examples as non-executable. Vignettes must not imply that
  a planned function already exists.
- Update documentation and `NEWS.md` for user-visible changes. Explain when
  an internal change needs no NEWS entry or additional tests.
- Keep documentation in English and wrap prose to a readable line length.

## Reporting a problem

Use the bug report form for observed behavior and a small reproducible example,
the feature form for user needs, the RFC form for design decisions, and the task
form for bounded implementation work. Include package and R versions when
relevant. Use simulated or de-identified data and omit private participant
information.

For methodological proposals, explain the observational assumptions and the
evidence that would validate the method. Do not claim benchmark performance
without reproducible results and a clear comparison.

## Pull requests

Explain the problem, the resulting behavior, and how the change was checked.
Link the issue and accepted RFC, identify generated files and dependencies,
and report any checks that could not run. Keep technical and methodological
review evidence in the PR so the maintainer can review the actual final change.
After a material revision, identify which earlier checks and reviews remain
applicable and obtain an updated technical review where needed.

## Releases

Only the maintainer decides and publishes releases. Intermediate milestones
do not generate releases; the next planned release is the experimental
`0.2.0` GitHub MVP once its agreed scope is complete. Later Bioconductor
preparation targets `0.99.0` through a separate maintainer decision. This is
a future target, not the current version or a claim of acceptance.

All contributions are covered by the repository's license and
[Code of Conduct](https://github.com/xec-cm/recoverome/blob/devel/CODE_OF_CONDUCT.md).
