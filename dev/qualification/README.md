# Qualification of the current descriptive method

Protocol registered in commit `42797a5`, with independent calendar review in
`4df2a8f`, before execution on 2026-09-10. See [protocol.md](protocol.md).
The public explanation and executable real example live in
[the real-data vignette](../../vignettes/real-data.Rmd), not in a second user guide.

## Reproduce

From the repository root, with development dependencies `pkgload` and `vegan`:

```sh
Rscript --vanilla dev/qualification/run.R
```

This uses the packaged data offline, writes the complete tables to `results/`,
and fails if independent arithmetic or synthetic rule assertions disagree.
The runner does not modify the method. It uses seed 20260910 and records RNG/R
and dependency versions in [session-info.txt](results/session-info.txt).
Timestamps in analytical provenance are not treated as numerical results.

Regenerate the dataset separately with `readxl`, using the original XLS:

```sh
Rscript --vanilla data-raw/dethlefsen2008.R path/to/original-sd003.xls
```

Omitting the path explicitly downloads the source; SHA-256 must match the pinned
file before any values are used. Calendar transcription is checked against the
original PDF Table 1. The packaged `DATA-LICENSE.md` preserves attribution and
identifies conversions. All 5,670 features and 18 sample columns are retained.

## Results and audit trail

| File | Rows | Purpose |
|---|---:|---|
| [synthetic.csv](results/synthetic.csv) | 96 | Baseline stability/selection and observation schedules. |
| [synthetic_rules.csv](results/synthetic_rules.csv) | 96 | Full prespecified rule grid on stable, fully observed scenarios. |
| [depth.csv](results/depth.csv) | 120 | Finite-count realizations and departures from generating compositions. |
| [real_rules.csv](results/real_rules.csv) | 216 | Every real episode, baseline selection and rule configuration. |
| [real_samples.csv](results/real_samples.csv) | 54 | Original times and deviations under each baseline selection. |
| [comparisons.csv](results/comparisons.csv) | 1,703 | Independent direct and vegan arithmetic comparisons. |
| [tied.csv](results/tied.csv) | 1 | Discordant simultaneous sample, candidate 4 and confirmation 8. |
| [historical.csv](results/historical.csv) | 1 | Removed supporting visit retains historical confirmation 6, with incomplete validation. |

Maximum absolute discrepancy was 2.21e-14 against direct arithmetic and 5.56e-17
against vegan, below the prespecified 1e-12 tolerance. Those comparisons concern
the observed values; `max_target_departure` separately measures sampling deviation
from generating compositions and is not subject to that arithmetic tolerance.

Synthetic primary outcomes matched the stated values and an independent base-R
visit classifier. Full return/rebound confirm at day 6; rebound first occurs at 8.
Sparse alternate visits lose confirmation. A missing bridge can delay it to day 10
when later visits remain; filtering after calculation instead retains day 6.
Under unstable baselines, the labels describe generating trajectories, not universal
expected classifications under every reference or rule.

Across real settings: 144 no-observed-return, 56 unconfirmed-return and 16
no-detected-perturbation outcomes; no confirmation. For all-baseline/primary-rule,
A/B/C each have no observed return and coverage reaches the horizon. This is not
proof of absence of biological recovery. The primary calendar cannot confirm the
required run regardless of distances, as recorded before execution. The broader
predeclared grid also produced no confirmations; no settings were expanded after
seeing this result.

The 120 finite-depth realizations all confirmed. Maximum target-distance departures
were .125, .0435 and .01325 at depths 100, 1,000 and 10,000 respectively. Twenty
replicates per depth/scenario do not calibrate error rates. This cohort has published
normalized abundances, so its original read depths are not inferred from column sums.

## Interpretation and subsequent decisions

This is a bounded method qualification, not a broad performance benchmark or
clinical validation. Numerical agreement, observation adequacy and biological
interpretation are separate. No estimator, distance or rule was changed.

Known limitations requiring separate decisions include unequal sample weighting
at tied baseline times, small and potentially variable baselines, feature-scope
sensitivity, unobserved behavior in gaps, and how to design future studies with
sufficient follow-up. Current equal sample weights and observational semantics
remain the accepted method. There is no automatic calibration, inference, causal
attribution or hidden optimization for a preferred outcome.

The proposed [sensitivity/plot contract](../rfcs/005-sensitivity-diagnostic-plots.md)
is the maintainer's acceptance gate for #44/#45. Approval requires merging this
shared #41/#43 PR; these APIs are not implemented here.
