
<!-- README.md is generated from README.Rmd. Please edit README.Rmd. -->

# nostos <img src="man/figures/logo.png" align="right" height="180" alt="NOSTOS: stacked stones and an orbit in a watercolor coastal hexagon." />

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R package
checks](https://github.com/xec-cm/nostos/actions/workflows/check-bioc.yml/badge.svg)](https://github.com/xec-cm/nostos/actions/workflows/check-bioc.yml)

**Describe microbiome return to a personal baseline under an explicit
observation rule.** Keep references, deviations, episode outcomes and
provenance in a TreeSummarizedExperiment (TSE). Similarity to baseline
does not establish health or continuous recovery between visits.

## Install

The experimental development branch requires R \>= 4.6.0. Version
`0.99.0` is an MVP and submission candidate, not a CRAN or Bioconductor
release.

``` r
install.packages("remotes")
remotes::install_github("xec-cm/nostos", ref = "devel")
```

The package was previously named `recoverome`. Install and load it as
`nostos`; existing saved analyses keep their original storage
identifiers. The repository and website now use `nostos` too. See the
[name
transition](https://github.com/xec-cm/nostos/blob/devel/dev/branding/README.md).

## A complete example

One participant, one explicit baseline (`b1`) and six follow-up visits.
This bundled synthetic example runs offline. Rule values are
illustrative, not recommended biological cutoffs.

``` r
data("recovery_examples", package = "nostos")
example_data <- recovery_examples$observed_recovery
raw <- TreeSummarizedExperiment::TreeSummarizedExperiment(
  assays = list(counts = example_data$counts),
  colData = S4Vectors::DataFrame(example_data$col_data)
)
tse <- nostos::setup_recovery(
  raw,
  analysis_id = "observed",
  episodes = example_data$episodes,
  events = example_data$events,
  time_col = "day",
  time_unit = "days",
  time_origin = "days since enrolment"
)
tse <- nostos::add_reference(tse, "observed", reference = "b1", assay = "counts",
                     preprocessing = "synthetic counts; no upstream transformations")
tse <- nostos::add_deviation(tse, "observed")
rule <- list(threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10)
tse <- nostos::add_recovery(tse, "observed", rule)

as.data.frame(nostos::recovery_results(tse, "observed"))[, c(
  "status", "candidate_time", "confirmation_time", "rebound_time"
)]
#>             status candidate_time confirmation_time rebound_time
#> 1 confirmed_return              2                 6            8
```

Return is observed on day **2**, confirmed by observations through day
**6**, and followed by a rebound on day **8**. Confirmation is not
permanent recovery.

``` r
nostos::plot_recovery(tse, "observed")
```

<img src="man/figures/README-plot-recovery-1.png" alt="Observed synthetic return at day 2, confirmation at day 6, then rebound at day 8."  />

## Learn more

- [Get started](https://xec-cm.github.io/nostos/articles/nostos.html):
  read the output and understand the seven-function workflow.
- [Prepare your
  data](https://xec-cm.github.io/nostos/articles/input-preparation.html).
- [Filtering and
  validation](https://xec-cm.github.io/nostos/articles/history-and-validation.html).
- [Real data and scientific
  limits](https://xec-cm.github.io/nostos/articles/real-data.html).

Filtering preserves history; `validate_recovery()` checks available
dependencies without recalculating results. No tidy adapter is required.
See the bounded [optional interoperability
assessment](https://github.com/xec-cm/nostos/blob/devel/dev/tidy-interoperability.md)
for verified operations and preservation limits.

Questions and reproducible problems belong in the [issue
tracker](https://github.com/xec-cm/nostos/issues). See
[CONTRIBUTING](.github/CONTRIBUTING.md) for development checks and the
[release preparation
record](https://github.com/xec-cm/nostos/blob/devel/dev/releases/0.99.0.md)
for publication status. Only the maintainer publishes releases or
submissions.

Maintainer: Francesc Catala-Moll
([ORCID](https://orcid.org/0000-0002-2354-8648)),
<fcatala@irsicaixa.es>.
