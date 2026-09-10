# Developer documentation

User explanations live in the installed vignettes:

- [Get started](../vignettes/recoverome.Rmd).
- [Input preparation](../vignettes/input-preparation.Rmd).
- [Filtering, history and validation](../vignettes/history-and-validation.Rmd).
- [Real data and scientific qualification](../vignettes/real-data.Rmd).

This directory keeps operational checks, accepted design history and reproducible
evidence. It is excluded from the source package by `.Rbuildignore`.

| Material | Purpose |
|---|---|
| [development-workflow.md](development-workflow.md), [r-style.md](r-style.md) | Issue, review and coding rules. |
| [architecture.md](architecture.md), [rfcs/](rfcs/) | Storage/API contracts and design decisions; RFC 005 was accepted through PR #49. |
| `check-*.R`, `resolve-bioc.R`, `coverage.R`, `tests/` | Executable maintenance and CI checks; retained intentionally. |
| [qualification/](qualification/) | Prespecified protocol, offline runner, full outputs and independent comparisons. |
| [tidy-interoperability.md](tidy-interoperability.md) | Bounded optional adapter assessment, versions and caveats; no required adapter. |
| [releases/](releases/), [bioconductor-readiness.md](bioconductor-readiness.md) | Dated release/readiness evidence; no automatic publication. |
| [examples/](examples/) | RFC 002/003 arithmetic evidence and the RFC 004 sketch; referenced PNG retained, duplicate SVG removed. |

## Integration evidence map

These tests establish container/contract behavior, not scientific validity or
support for arbitrary future TSE operations. Expected values are independent of
the result under test. See the qualification directory for scientific scenarios.

| Operation | Evidence in `tests/testthat/` |
|:----------|:-----------------------------|
| Registration preserves assays, annotations, trees, links and unrelated metadata; failures leave the input unchanged. | `test-setup-recovery.R`, `test-setup-recovery-invalid.R`, `test-registration-errors.R`. |
| Independently reorder samples, features, episodes and events; compare equivalent factor/integer metadata by identity. | `test-setup-recovery.R`, `test-validate-recovery.R`, `test-tse-preservation.R`. |
| Register, reorder and filter a TSE whose tree tip order differs from assay identities; retain the trees, selected links and registration history. | `test-tse-preservation.R`. |
| Filter samples/features, lose a whole episode, keep only excluded samples, or select empty axes. | `test-validate-recovery.R`. |
| Register a second analysis on a subset with its own time selector; edit that selector and check which analysis reports a change. | `test-tse-preservation.R`. |
| Rename identities after selection; distinguish removed/new IDs from retained metadata changes without guessing correspondence. | `test-validate-recovery.R`, `test-tse-preservation.R`. |
| Change unrelated annotations or assay values; registration dependencies remain unchanged. | `test-validate-recovery.R`. |
| Validate repeatedly, including objects with findings, without mutating or repairing the input. | `test-validate-recovery.R`, `test-tse-preservation.R`. |

| Issue criterion | Evidence in `tests/testthat/` |
|:----------------|:-----------------------------|
| Follow-up ends before return, between candidate and confirmation, or after confirmation | `test-recovery-history.R`: fresh prefixes of one trajectory contrasted with filtered completed analyses. |
| Irregular visits, long gaps and rebounds | Existing `test-add-recovery.R`: nine accepted worked trajectories, a failed run followed by confirmation, a gap of five days exceeding the maximum of three, rebound preservation and exact boundaries. |
| Remove visits supporting the original outcome without recomputing | `test-recovery-history.R`: removal by evidence role, all samples removed, tied discordance and coverage beyond the horizon. |
| Diagnose missing evidence and broken dependencies | `test-recovery-history.R`: explicit missing IDs and incomplete checks; `test-recovery-multi-analysis.R`: edited owned outputs and the recovery-to-deviation parent fingerprint. Existing `test-validate-outcomes.R` covers simultaneous missing-input and changed-result findings. |
| Distinguish original/current scope across named analyses | `test-recovery-multi-analysis.R`: full and newly shortened analyses in one reordered TSE, per-analysis counts/diagnostics and subsequent shared filtering. |
| Record unsupported patterns and protect actual failures | This document describes explicit rerunning and supported historical interpretation. The integration cases passed without requiring a production correction. |

Extraction evidence lives in `tests/testthat/test-recovery-results*.R`: retained,
removed and not-computed rows, typed empty views, changed inputs versus corrupted
outputs, context, original identity order and independent named analyses. Plotting
tests verify data/evidence layers; representative figures also require visual review.

Earlier issue-specific guides (`analytical-validation`, `observed-recovery`,
`recovery-history`, `result-extraction`, `tse-preservation`) are consolidated into
the installed guides, function help, architecture/RFCs and this evidence map.
Their original dated evidence remains in git history at
[the prior revision](https://github.com/xec-cm/recoverome/tree/663bd0269055c0f825e06267d10b43ed2da41b91/dev).
Do not maintain duplicate current user explanations in new issue reports.
