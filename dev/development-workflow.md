# Development workflow

This document defines how recoverome work moves from a proposal to a reviewed
change. It does not select statistical methods or make unimplemented API
functions available.

The development version implements `setup_recovery()` for registration and
`validate_recovery()` for registration and analytical dependency diagnostics,
and `add_reference()` for personal baseline profiles. `add_deviation()` records
sample deviations from those profiles. `add_recovery()` attaches observed
episode outcomes. `recovery_results()` extracts tables with historical context;
`plot_recovery()` displays saved observations and evidence. The next target is an
experimental **0.99.0 MVP and Bioconductor submission candidate**. Its original seven-function workflow is:
`setup_recovery()`, `add_reference()`, `add_deviation()`, `add_recovery()`,
`recovery_results()`, `plot_recovery()`, and `validate_recovery()`.
Use the [architecture contract](https://github.com/xec-cm/recoverome/blob/devel/dev/architecture.md)
for their responsibilities. The maintainer authorized direct Bioconductor
preparation alongside the MVP on 2026-09-10; publication and submission remain
separate decisions.

## Tracking work

Use the public
[recoverome Development project](https://github.com/users/xec-cm/projects/10)
and repository issues. Native project auto-add includes issues only. Keep one
project card per issue and link its PR from that issue; do not add a second
card for the PR. Dependabot PRs remain in the repository's PR list rather than
creating duplicate project cards.

The project owns the status and native priority fields; do not create
duplicate status or priority labels. The maintainer reviews priorities and
the `Ready` queue weekly, taking dependencies and available review capacity
into account.

| Priority | Meaning |
|:---------|:--------|
| P0 | Urgent blocker preventing reliable development or release. |
| P1 | Essential (imprescindible) work in the current delivery plan. |
| P2 | High-relevance improvements (alta relevancia). |
| P3 | Optional work (optativo). |

Issue type labels are `bug`, `enhancement`, `documentation`, `design`, `testing`,
`infrastructure`, `dependencies`, and `release`. RFCs use `design`; an RFC's
acceptance requires the maintainer to merge its short design-document PR.
An issue comment or label does not replace that merged document.

Milestones group work into these phases:

| Milestone | Scope |
|:----------|:------|
| M0 | Development workflow and infrastructure. |
| M1 | Data contracts and validation. |
| M2 | Reference and deviation infrastructure. |
| M3 | Observed recovery workflow. |
| M4 | Experimental GitHub MVP. |
| M5 | Bioconductor submission preparation. |
| M6 | Clear documentation and maintainable validation. |
| M7 | Scientific qualification and explicit rule sensitivity. |
| M8 | Useful diagnostics and external user evaluation. |

An issue represents a complete reviewable delivery; its internal steps are
acceptance checkboxes, not issues per helper, file or vignette. The maintainer
explicitly authorized #41 and #43 in one shared PR on branch `codex/issue-41`.
Both active issues count toward the two-issue limit; #43 is not assigned separately
to avoid a duplicate bootstrap PR. Both closure references remain in the shared PR.
This exception does not authorize starting their dependent implementations before
RFC 005 is merged or replacing external-user evaluation with agent review.

The published issue backlog is the task inventory. Use its dependencies and
acceptance criteria rather than creating a second, diverging checklist here.

## States and readiness

Work follows `Backlog` → `Ready` → `In progress` → `Review` → `Done`.

| State | Meaning and exit condition |
|:------|:---------------------------|
| Backlog | Proposed work awaiting scope, dependency, or design decisions. |
| Ready | A bounded task whose dependencies and design prerequisites are resolved. |
| In progress | Work and independent technical review are underway on the issue branch. |
| Review | Technical review is complete, findings resolved, and maintainer review is next. |
| Done | The issue is closed after its maintainer-merged PR completes the work. |

Keep **at most two issues in `In progress` and `Review` combined**. A draft PR
does not exempt its active issue from this limit. Work waiting for review
continues to count. Finish or unblock active work before starting another item.
Preparing a branch or draft PR by assignment does not itself launch work.

Before moving an implementation task to `Ready`, confirm:

1. Its objective and acceptance criteria describe a reviewable outcome.
2. Blocking implementation dependencies are completed and available in `devel`.
3. Each required RFC exists as a short design document whose PR the maintainer
   has merged into `devel`, including any conditions that affect the task.
4. The expected tests, documentation, NEWS impact, and dependency changes are
   identified. No additional statistical decision is hidden in the task.

An RFC task produces a short design document and follows the same branch,
technical review, and maintainer-merged PR workflow as implementation work.
The document records the decision, relevant alternatives and assumptions, and
validation expectations. Its own proposal need not already be accepted before
the document is drafted. Dependent implementation remains in `Backlog` until
the maintainer merges that RFC PR. Closing the issue or expressing agreement
in a comment without a merged RFC does not unblock dependent work.

If new information invalidates readiness, record the blocker and return the
task to the appropriate earlier state. Do not move an issue simply to hide
active work from the limit. Review changes can return an issue to `In progress`
without adding another active slot.

## Assignment, branches, and sessions

Assign a ready issue to its intended implementer. The assignment workflow
prepares branch `codex/issue-N`, where `N` is the issue number, and a draft PR
against `devel`. Treat that branch and PR as the shared record for the issue;
reuse them on reassignment or resumption.

The assignment automation returns early when the branch already exists. If a
partial failure created `codex/issue-N` but not its PR, reassignment will not
repair the missing PR. First check whether a PR already exists for that branch.
If none exists, reuse the branch and create exactly one draft PR with base
`devel` and `Closes #N` in its description. Do not delete or recreate the branch.
Report any visible workflow approval request using the process below.

Assignment is preparation, not an instruction to launch an agent session.
Starting an agent requires explicit user authorization for that session or an
active task whose scope already authorizes the work. Do not request another
permission for routine steps already covered by that authorization.

The implementation agent works in an isolated worktree checked out on the
issue branch. It must verify the branch, issue, and worktree before editing,
preserve existing commits and user changes, and avoid destructive resets or
force pushes. Parallel agents must have explicit, non-overlapping ownership
when sharing a worktree.

Keep the draft PR current while work proceeds. Include the linked issue, RFC
decision, implementation scope, evidence from checks, and known blockers.
When the accepted criteria are implemented, request independent technical
review while the issue remains `In progress`. Resolve the findings and record
the completed review before moving the issue to `Review` and making the PR
ready for the maintainer's final review.

## Two review responsibilities

An **independent agent** provides technical review. The implementation agent
cannot satisfy this requirement through self-review. The review may be
recorded as a PR comment or linked review artifact; a formal GitHub approval
from a separate agent account is not required.

The technical review record must contain:

- A reviewer name or session identity distinct from the implementation agent.
- The reviewed commit and the scope examined.
- Checks run or inspection performed, including limitations.
- Findings, their severity, and their documented resolution.

The reviewer must confirm that findings are resolved and no required change
remains open before the issue enters `Review`.

The reviewer also checks readability against `dev/r-style.md`: shallow control
flow, cohesive responsibilities and clear data flow. Passing tests or moving
nested code into a helper does not replace this inspection. Resolve unnecessary
deep nesting and ensure guard clauses preserve shared diagnostic bookkeeping.

The reviewer assesses implementation against the accepted contract. Unresolved
methodological questions are referred to the maintainer rather than decided
implicitly in a code review. After material changes, obtain an updated review
covering the changes; do not reuse an obsolete review as final approval.

The **maintainer** reviews methodology, assumptions, scope, and the final
change. Record the decision in the PR discussion. Every PR is squash-merged
by the maintainer, including documentation and infrastructure changes.
**Agents must never merge PRs or enable auto-merge.**

Before merge, the branch must be up to date with `devel` and these required
checks must pass:

- `R package checks`
- `quality`
- `Build the documentation site`

Passing checks does not replace technical review or the maintainer's decision.
Use `Closes #N` in the PR description. The maintainer's merge into `devel`
closes the linked issue, and the native project workflow moves the closed
issue to `Done`. Verify this outcome after merge; do not use a manual move to
`Done` as the primary completion action. Moving a project card to `Done` alone
does not close its issue. RFC issues follow this same merged-PR closure path.

## Evidence required from a change

Tests must cover meaningful implemented behavior and failure modes. Do not add
stubs, placeholder output, or tests that merely repeat an implementation.
For numerical code, include small deterministic R examples with independently
checkable expected values and explicit numerical tolerances where needed.
Use coverage reports to identify untested behavior; do not impose an arbitrary
percentage target. If no executable tests exist yet, report coverage as
unavailable rather than zero or a fabricated passing value.
Documentation must distinguish planned and available functionality. Update
`NEWS.md` for user-visible changes; explain when an internal change needs no
release note or additional test.

Each new dependency needs a concrete justification and implemented code that
uses it. Avoid speculative runtime dependencies. Generate R documentation
using the roxygen2 version pinned in `DESCRIPTION` under
`Config/Needs/quality` and `Config/roxygen2/version`. Updating that pin is an
explicit tooling change with generated output reviewed in the same PR.

Run checks from the repository root with a clean R session:

```sh
Rscript --vanilla dev/check-package.R
Rscript --vanilla dev/check-generated.R
Rscript --vanilla dev/check-bioc.R
```

Run the package check before the Bioconductor check because the latter uses
the built package artifact. The Bioconductor check is informative at this
stage; its presence does not imply submission or acceptance. Report actual
outcomes and any unrun checks rather than claiming a blanket pass.

## Release authority and versions

Completing an intermediate milestone does not trigger a package release. On
2026-09-10 the maintainer replaced the unpublished `0.2.0` MVP target with
`0.99.0` and authorized direct Bioconductor preparation in the shared #21/#22
PR. This is a specific exception to separate issue branches and to merging
#21 before beginning #22; other issue readiness rules are unchanged.

The current artifact is an experimental MVP and initial submission candidate.
See [release preparation](releases/0.99.0.md) for evidence and publication steps,
and [Bioconductor readiness](bioconductor-readiness.md) for remaining obligations.
Only the maintainer may create a release tag, publish a GitHub prerelease,
change external account settings or submit the package. No acceptance is implied
by the version number or by successful package checks.

## Workflow approval states

PRs created or updated using `GITHUB_TOKEN` may display
`Approve workflows to run`. If GitHub shows this state, tell the maintainer
which workflow is waiting and retain the visible status in the PR record.
Do not claim the checks passed or failed before they have run.

Keep the configured authentication. Do not replace tokens, broaden credential
permissions, or make unrelated writes to bypass this state. The maintainer
handles any approval GitHub requests through the existing interface.
