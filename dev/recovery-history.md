# Observed recovery under incomplete follow-up and filtering

This evidence map covers [issue #15](https://github.com/xec-cm/recoverome/issues/15)
and the existing [RFC 003](rfcs/003-observed-recovery.md) contract. It combines
the calculation tests from issue #14 with integration tests through the public
setup, reference, deviation, recovery and validation functions. No analytical
rule, result schema, dependency or replacement operation is introduced here.

## A short study and a shortened view are different analyses

The bundled `observed_recovery` fixture has a baseline composition (1, 0),
follow-up times 0, 2, 4, 6, 8 and 10, and deviations 0.75, 0.25, 0.125, 0.125,
0.5 and 0.125. For illustration, the rule is threshold 0.25, persistence 4,
maximum gap 3 and horizon 10, with durations in registered days.

When only the stated prefix is available **before registering and calculating**,
the independently expected results are:

| Last observed day | Status | Candidate | Confirmation | Rebound | Coverage |
|:------------------|:-------|----------:|-------------:|--------:|:---------|
| 0 | `no_observed_return` | NA | NA | NA | `ends_before_horizon` |
| 4 | `unconfirmed_return` | 2 | NA | NA | `ends_before_horizon` |
| 6 | `confirmed_return` | 2 | 6 | NA | `ends_before_horizon` |
| 8 | `confirmed_return` | 2 | 6 | 8 | `ends_before_horizon` |

A lack of confirmation at day 4 describes the available observations. A
confirmation at day 6 can coexist with follow-up ending before the horizon.
Neither outcome establishes the continuous state through day 10.

When the complete analysis is calculated first and **then filtered to those
same samples**, its historical confirmation remains day 6, rebound remains
day 8, and recorded follow-up remains day 10. The assays of the fresh and
historical subsets agree, but their analytical histories differ. The validator
reports missing recorded inputs and incomplete checks; it does not change the
outcome, its evidence, provenance or fingerprints.

To calculate a new subset analysis, register another name and explicitly run
its reference, deviation and recovery stages. Its inputs must still satisfy
the accepted contracts, including episode membership and baseline eligibility.
Adding recovery to an old deviation stage after dropping samples is unsupported;
there is no implicit refresh or overwrite operation.

## Evidence removal and multiple analyses

Removing the baseline, perturbation, candidate, confirmation, rebound or latest
coverage observation retains the entire named record. This also holds after
reordering retained samples or removing every sample. `RECOVERY_INPUT_MISSING`
identifies the removed recorded inputs; history remains interpretable as history,
not a newly validated outcome for the remaining measurements.

Two further examples guard against misleading reinterpretation:

- At a tied day-2 visit, one outside observation can delay the original candidate
  to day 4 and confirmation to day 8. Removing that discordant sample later
  preserves those dates. A newly registered analysis without it can instead
  start at day 2 and confirm at day 6.
- A day-12 outside observation contributes coverage under horizon 10, but cannot
  count as a rebound. Removing it retains the recorded last observation at 12
  and coverage `reaches_horizon`, with incomplete validation.

A full seven-sample analysis and a new four-sample analysis can coexist in one
filtered TSE. The first reports original/retained counts 7/4, a reduced scope
and incomplete comparisons; the second reports 4/4, its own full scope and
complete comparisons. An edited owned deviation or parent record in the second
analysis produces its own dependency error without marking the first analysis
as changed. A subsequent shared subset preserves both independent histories.

## Acceptance evidence

All numerical expectations and identities are stated in the tests, independent
of the result being checked. The tests reuse `recovery_examples` and existing
fixture constructors, without downloading cohorts or adding dependencies.

| Issue criterion | Evidence in `tests/testthat/` |
|:----------------|:-----------------------------|
| Follow-up ends before return, between candidate and confirmation, or after confirmation | `test-recovery-history.R`: fresh prefixes of one trajectory contrasted with filtered completed analyses. |
| Irregular visits, long gaps and rebounds | Existing `test-add-recovery.R`: nine accepted worked trajectories, a failed run followed by confirmation, a gap of five days exceeding the maximum of three, rebound preservation and exact boundaries. |
| Remove visits supporting the original outcome without recomputing | `test-recovery-history.R`: removal by evidence role, all samples removed, tied discordance and coverage beyond the horizon. |
| Diagnose missing evidence and broken dependencies | `test-recovery-history.R`: explicit missing IDs and incomplete checks; `test-recovery-multi-analysis.R`: edited owned outputs and the recovery-to-deviation parent fingerprint. Existing `test-validate-outcomes.R` covers simultaneous missing-input and changed-result findings. |
| Distinguish original/current scope across named analyses | `test-recovery-multi-analysis.R`: full and newly shortened analyses in one reordered TSE, per-analysis counts/diagnostics and subsequent shared filtering. |
| Record unsupported patterns and protect actual failures | This document describes explicit rerunning and supported historical interpretation. The integration cases passed without requiring a production correction. |

These are deterministic contract and preservation checks. They provide no
threshold calibration, benchmark result, confidence interval, missing-data
imputation, latent event-time estimate or guarantee for arbitrary external TSE
transformations. Optional tidy operations remain the separate work in issue #19.
See [analytical validation](analytical-validation.md) for diagnostic boundaries.
