# TSE preservation and historical scope

This evidence map covers the implemented registration workflow under
[RFC 001](rfcs/001-registration-validation.md), including the integration work
in [issue #8](https://github.com/xec-cm/recoverome/issues/8). It describes tested
operations, not a guarantee for arbitrary container transformations.

## What remains historical

`setup_recovery()` adds a named registration and preserves the supplied TSE
content. `validate_recovery()` reads that registration and the current object;
it returns a report without changing either. Ordinary `tse[rows, columns]`
subsetting is performed by TSE itself. Recoverome does not intercept it.

The stored sample snapshot, episode/event tables and original sample/feature
scope remain those of registration. The report compares retained identities
with that history. A reduced scope and a change to consumed metadata are
separate findings. Removing every sample from an episode does not invalidate
its historical episode or event records.

Registering another name on a subset is an explicit new registration. Its
scope is the subset at that call, while the earlier analysis retains its own
scope and source-column bindings. The new registration still needs to satisfy
RFC 001, including an included sample for each supplied episode.

## Test evidence

All fixtures use the small bundled `recovery_examples`; no external cohort or
new runtime dependency is needed. Expected identities, times, counts and
report states are stated independently of the function results.

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

The linked-tree scenario checks node associations against explicitly stated
values, not only equality with another result produced by recoverome. The
multiple-analysis scenario checks all-analysis and selected-analysis reports,
as well as preservation of both records. These integration cases complement
the focused contract tests rather than repeat their invalid-input matrix.

## Interpretation and boundaries

- Pure reordering has scope `same`. Subsetting retains a valid historical
  registration and reports `subset` or `empty`; it does not certify the
  unavailable values of removed samples.
- A finite change to a retained included sample's consumed time can yield
  `structural_valid = TRUE` and `dependencies = "changed"`. An intact snapshot
  is distinct from agreement with the current source metadata.
- Renaming an ID is a removal plus an addition. A tree link or equal assay
  values do not establish that the new ID is the old sample. Duplicate IDs
  remain ambiguous even when the container passes formal S4 validity.
- The linked-tree integration case uses deterministic trees on both axes and
  standard bracket subsetting. It does not establish support for every tree
  editing, aggregation, pruning or alternate-experiment operation. Native TSE
  subsetting can drop trees and links for empty axes or unrepresented trees;
  recoverome preserves the container supplied to its own calls, not a promise
  that every TSE operation retains every original tree.
- Registration does not consume assay values, estimate references or validate
  analytical results. Changing an assay is outside its dependency check.
  Later analytical stages must implement the additional contracts in RFC 002.
- Tidy wrappers and their transformations need the separate interoperability
  assessment in issue #19. These tests add no tidy compatibility claim.
- Manual editing of stored recoverome snapshots remains unsupported. Structural
  validation is not a tamper-proof audit trail, and it never repairs history.

Run the package suite and package checks from the repository root as described
in [the development workflow](development-workflow.md). CI records the R and
Bioconductor environments used; a passing run supports the tested operations
in those environments, not future container versions or untested backends.
