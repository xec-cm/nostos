
<!-- README.md is generated from README.Rmd. Please edit README.Rmd. -->

# recoverome

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R package
checks](https://github.com/xec-cm/recoverome/actions/workflows/check-bioc.yml/badge.svg)](https://github.com/xec-cm/recoverome/actions/workflows/check-bioc.yml)

**A package in development for studying microbiome recovery after a
perturbation.**

`recoverome` aims to make recovery definitions explicit and
reproducible: what reference a sample is compared with, what counts as a
return, how long that return must persist, and what the sampling
schedule can support.

Version 0.1.0 is an experimental package scaffold. It provides project
documentation and development infrastructure. **It does not yet
implement recovery analysis functions.** The interface below is a design
proposal.

Read the [documentation](https://xec-cm.github.io/recoverome/) and the
[architecture
contract](https://github.com/xec-cm/recoverome/blob/devel/dev/architecture.md)
for the current scope.

## Why recovery needs its own analysis

A microbiome can approach its initial composition at one visit and move
away at the next. A single pre-intervention sample cannot describe an
individual’s usual variation. Long gaps between visits also limit the
precision of a recovery time.

The planned package will distinguish observed return from sustained
return under a stated observation rule. It will keep the reference
definition, sampling coverage, and analysis provenance attached to the
data. A lack of statistical significance against baseline will not be
treated as proof of recovery.

The initial design focuses on longitudinal profiles with a known
perturbation and a prespecified reference. Recovery to a personal
baseline describes similarity to that baseline; it does not establish
health or functional restoration.

## Install the development scaffold

The development branch is `devel`. There is no CRAN or Bioconductor
release.

``` r
install.packages("remotes")
remotes::install_github("xec-cm/recoverome", ref = "devel")
```

## Planned workflow

The proposed interface extends a `TreeSummarizedExperiment` (TSE).
Functions that add analysis information will return a TSE, retaining the
original assays and sample identities. This allows recovery annotations
to travel with the data through existing Bioconductor workflows.

| Planned function | Responsibility |
|:---|:---|
| `setup_recovery()` | Register a named analysis, episodes, and events. |
| `add_reference()` | Record the reference definition and eligible samples. |
| `add_deviation()` | Attach deviations from the registered reference. |
| `add_recovery()` | Attach outcomes under an explicit recovery rule. |
| `recovery_results()` | Extract results at the requested analysis level. |
| `plot_recovery()` | Display observations and the recovery definition. |
| `validate_recovery()` | Check whether an analysis still matches its data. |

The following is **non-executable proposed API**, not a working example.
The design requires maintainer acceptance and subsequent implementation.

[RFC
001](https://github.com/xec-cm/recoverome/blob/devel/dev/rfcs/001-registration-validation.md)
specifies the registration and validation proposal. Sample-to-episode
membership is explicit in `colData()`; times use a declared numeric
coordinate system.

``` r
tse <- setup_recovery(
  tse,
  analysis_id = "antibiotic",
  episodes = episodes,
  events = events,
  time_col = "day",
  time_unit = "days",
  time_origin = "days relative to exposure start within each participant"
)
tse <- add_reference(tse, analysis_id = "antibiotic", reference = reference)
tse <- add_deviation(tse, analysis_id = "antibiotic")
tse <- add_recovery(tse, analysis_id = "antibiotic", rule = recovery_rule)

validate_recovery(tse, analysis_id = "antibiotic")
recovery_results(tse, analysis_id = "antibiotic", level = "episode")
plot_recovery(tse, analysis_id = "antibiotic")
```

The [introductory
vignette](https://xec-cm.github.io/recoverome/articles/recoverome.html)
contains an executable example of the input TSE structure. It makes no
recovery claims from that toy dataset.

## Data and result contracts

- Sample annotations will use `rec_<analysis>_` prefixes in `colData()`;
  for example, `rec_antibiotic_deviation`. Analysis IDs will be simple,
  stable identifiers matching `^[a-z][a-z0-9]*$`, preventing overlapping
  prefixes. Registration reserves the prefix and records history in
  metadata; sample result columns belong to later analytical stages.
- Episode, event, reference, and provenance records will live in named
  analyses under `metadata(tse)$recoverome`.
- Filtering a TSE will retain historical analysis records with their
  original scope. It will not silently recompute a reference or recovery
  outcome.
- Validation will make differences between the current data and the
  original analysis scope explicit before results are reused.

These are intended contracts, not implemented behavior in this scaffold.
Statistical fitting, group comparisons, and recovery-time uncertainty
methods are outside the initial seven-function interface and require
separate design and validation.

## Development and contributions

The next step is to implement and validate the data contracts before
adding analytical methods. No benchmark performance or statistical
guarantees are claimed for this version.

See [CONTRIBUTING](.github/CONTRIBUTING.md) for local checks and
contribution guidelines. Please use the [issue
tracker](https://github.com/xec-cm/recoverome/issues) to discuss designs
or report a reproducible problem.

Maintainer: Francesc Catala-Moll
([ORCID](https://orcid.org/0000-0002-2354-8648)),
<fcatala@irsicaixa.es>.
