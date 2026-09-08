## Problem and resulting behavior

Describe the concrete problem and what this change enables or corrects.
Distinguish implemented behavior from design proposals.

## Issue, design, and scope

- Linked issue with `Closes #N` and acceptance criteria:
- Merged RFC document PR, or why no prerequisite RFC applies to this PR:
- Blocking dependencies and their resolution:
- Work intentionally outside this PR:

## Validation

List checks actually run, their outcomes, and the relevant commit. Explain
checks that could not run or were unnecessary. For an analytical change, link
the accepted methodology and describe validation evidence without inventing
results.

- Tests and failure modes, including small numerical R examples where relevant:
- Coverage findings, or why additional tests or coverage are not applicable:
- Documentation and generated files; pinned roxygen2 version used:
- NEWS entry, or why none is needed:
- New dependencies and justification, or none:
- Required CI and branch freshness; any visible workflow approval needed:

## Independent technical review

Link the independent agent's review record before requesting maintainer review.
The record must include:

- Reviewer identity or session, distinct from the implementation agent:
- Reviewed commit:
- Scope examined and checks performed:
- Findings and documented resolution of each:

Refresh this review after material changes. CI and self-review do not replace
independent review; a formal GitHub approval from an agent account is not
required. Keep the issue `In progress` while technical review is incomplete or
required changes remain open. Move it to `Review` only when that review is
complete and its findings have been resolved.

## Maintainer review

Identify methodological decisions, API changes, scope/provenance effects, or
limitations that need the maintainer's judgment. Record the maintainer's
decision in the PR discussion.

Only the maintainer squash-merges this PR. Agents must not merge or enable
auto-merge. Required checks are `R package checks`, `quality`, and
`Build the documentation site`, with the branch up to date with `devel`.
The merge closes the issue through `Closes #N`, and native project automation
sets `Done`; changing project status alone does not close the issue. For an
RFC, maintainer merge of the short design document is the acceptance record.
