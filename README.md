
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

The experimental development version provides `setup_recovery()` to
register a named analysis with explicit episodes, events, and sample
membership. `validate_recovery()` diagnoses the registered structure,
changes to consumed metadata, and the relationship between current and
original scope. `add_reference()` attaches a personal reference from
explicitly selected baseline samples. Deviation, recovery outcomes,
plotting, and extraction remain planned.

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

## Install the development version

The development branch is `devel`. There is no CRAN or Bioconductor
release.

``` r
install.packages("remotes")
remotes::install_github("xec-cm/recoverome", ref = "devel")
```

## Register an analysis

`setup_recovery()` takes a `TreeSummarizedExperiment` (TSE) and returns
it with a registration in its metadata. It preserves assays and sample
annotations. Here, three samples belong to one episode, whose origin is
the start of an exposure interval. All times are numeric days since
enrolment. The package includes two small synthetic cases:
`single_episode` and `repeated_episodes`. The latter adds a second
episode and an explicitly excluded sample. Their matrices and tables are
shared by the executable examples and tests.

``` r
data("recovery_examples", package = "recoverome")
example_data <- recovery_examples$single_episode

tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
  assays = list(counts = example_data$counts),
  colData = S4Vectors::DataFrame(example_data$col_data)
)
```

The episode and event tables are supplied explicitly. Registration
checks their identities and references, records the time declaration,
and stores normalized `S4Vectors::DataFrame` tables. It does not select
reference samples or calculate recovery.

``` r
tse <- recoverome::setup_recovery(
  tse,
  analysis_id = "antibiotic",
  episodes = example_data$episodes,
  events = example_data$events,
  time_col = example_data$time_col,
  time_unit = example_data$time_unit,
  time_origin = example_data$time_origin
)
registration <- S4Vectors::metadata(tse)$recoverome$analyses$antibiotic
registration$registration$samples
#> DataFrame with 3 rows and 4 columns
#>     sample_id    subject_id  episode_id      time
#>   <character>   <character> <character> <numeric>
#> 1          s1 participant_1   episode_1         3
#> 2          s2 participant_1   episode_1        10
#> 3          s3 participant_1   episode_1        17
```

Filtering keeps the original registration snapshot. The retained sample
below is `s3`, while the stored sample scope still contains all three
original IDs.

``` r
follow_up <- tse[, "s3", drop = FALSE]
colnames(follow_up)
#> [1] "s3"
S4Vectors::metadata(follow_up)$recoverome$analyses$antibiotic$scope$sample_ids
#> [1] "s1" "s2" "s3"
report <- recoverome::validate_recovery(follow_up, analysis_id = "antibiotic")
report$summary
#> DataFrame with 1 row and 8 columns
#>   analysis_id structural_valid validation_complete dependencies sample_scope
#>   <character>        <logical>           <logical>  <character>  <character>
#> 1  antibiotic             TRUE                TRUE    unchanged       subset
#>   feature_scope n_registered n_retained
#>     <character>    <integer>  <integer>
#> 1          same            3          1
```

The registration remains structurally valid, with unchanged retained
metadata and a reduced sample scope: one of the three registered samples
remains. The report does not modify the object or check assay values.
Its diagnostics separate missing historical observations from changed
metadata or broken records.

See the [introductory
vignette](https://xec-cm.github.io/recoverome/articles/recoverome.html)
for the stored records and filtering example in more detail. This small
dataset illustrates registration only; it does not establish recovery.

## Attach a personal reference

Select baseline sample IDs explicitly and name the assay. Each selected
sample must precede the start of its episode’s origin event, even if the
episode uses that event’s end as its time origin. The function closes
each selected sample to proportions over the chosen features, then
averages samples equally within each episode. It performs no implicit
filtering, pseudocount addition or preprocessing beyond that declared
closure.

``` r
referenced <- recoverome::add_reference(
  tse,
  analysis_id = "antibiotic",
  reference = "s1",
  assay = "counts",
  preprocessing = "synthetic counts; no upstream transformations"
)
personal <- S4Vectors::metadata(referenced)$recoverome$analyses$antibiotic$reference
personal$profiles
#>           episode_1
#> feature_a       0.8
#> feature_b       0.2
personal$episodes
#> DataFrame with 1 row and 7 columns
#>    episode_id       support n_samples   n_times first_time last_time
#>   <character>   <character> <integer> <integer>  <numeric> <numeric>
#> 1   episode_1 single_sample         1         1          3         3
#>   baseline_diameter
#>           <numeric>
#> 1                NA
```

Here the reference is `(0.8, 0.2)`, with `single_sample` support and an
undefined baseline diameter (`NA`), since one observation cannot
describe temporal variation. A reference is descriptive: it is not a
healthy-state estimate or an automatic recovery threshold. Selection and
input fingerprints are retained with the profile; assays and unrelated
TSE content remain unchanged.

The current `validate_recovery()` still supports registration only. A
reference record therefore produces `STAGE_UNSUPPORTED` and incomplete
validation; adding the reference does not claim that its analytical
dependencies have been checked by that separate diagnostic function.
Stage-aware validation is planned in \#12.

## Available and planned workflow

| Function | Status | Responsibility |
|:---|:---|:---|
| `setup_recovery()` | Available | Register a named analysis, episodes, and events. |
| `add_reference()` | Available | Attach personal reference profiles, support and input provenance. |
| `add_deviation()` | Planned | Attach deviations from the registered reference. |
| `add_recovery()` | Planned | Attach outcomes under an explicit recovery rule. |
| `recovery_results()` | Planned | Extract results at the requested analysis level. |
| `plot_recovery()` | Planned | Display observations and the recovery definition. |
| `validate_recovery()` | Available | Diagnose registration records, metadata changes, and current scope. |

Analysis IDs match `^[a-z][a-z0-9]*$`. Registration reserves the
corresponding `rec_<analysis>_` prefix but creates no sample result
columns. A repeated analysis ID or an existing column under its prefix
is an error; use a new analysis name to register another analysis.

[RFC
001](https://github.com/xec-cm/recoverome/blob/devel/dev/rfcs/001-registration-validation.md)
defines registration and its validation report. Filtering does not enrol
new samples or reinterpret the historical record. Statistical fitting,
group comparisons, and recovery-time uncertainty methods require
separate design and validation.

## Development and contributions

The next steps are deviation calculation, analytical dependency
validation and observed recovery outcomes under the accepted contracts.
No benchmark performance or statistical guarantees are claimed for this
version.

See [CONTRIBUTING](.github/CONTRIBUTING.md) for local checks and
contribution guidelines. Please use the [issue
tracker](https://github.com/xec-cm/recoverome/issues) to discuss designs
or report a reproducible problem.

Maintainer: Francesc Catala-Moll
([ORCID](https://orcid.org/0000-0002-2354-8648)),
<fcatala@irsicaixa.es>.
