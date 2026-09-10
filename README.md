
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
changes to consumed inputs or stored results, and the relationship
between current and original scope. It checks the stages that are
present without changing the TSE. `add_reference()` attaches a personal
reference from explicitly selected baseline samples. `add_deviation()`
measures sample dissimilarity from those fixed profiles.
`add_recovery()` attaches observed episode outcomes under an explicit
rule. `plot_recovery()` displays observations and saved time evidence.
`recovery_results()` extracts sample or episode tables with historical
context and current validation flags.

Read the [documentation](https://xec-cm.github.io/recoverome/) and the
[architecture
contract](https://github.com/xec-cm/recoverome/blob/devel/dev/architecture.md)
for the current scope.

## Why recovery needs its own analysis

A microbiome can approach its initial composition at one visit and move
away at the next. A single pre-intervention sample cannot describe an
individual’s usual variation. Long gaps between visits also limit the
precision of a recovery time.

The package distinguishes an observed return from confirmation supported
by later visits under a stated observation rule. It keeps the reference
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
enrolment. The package includes small synthetic cases: `single_episode`,
`repeated_episodes`, and `observed_recovery`. `repeated_episodes` adds a
second episode and an explicitly excluded sample; `observed_recovery`
illustrates confirmation followed by a rebound. Their matrices and
tables are shared by the executable examples and tests.

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
dataset illustrates the data contracts; it does not establish recovery.

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

`validate_recovery()` can check this reference against its saved record
and current baseline inputs. Limited support is reported as information;
a single baseline is not itself a broken analysis.

## Calculate sample deviations

`add_deviation()` uses the assay and feature set recorded by
`add_reference()`. It checks that the selected baselines and their
inputs are still available and unchanged, then compares each included
sample composition with its fixed episode profile using Bray–Curtis
dissimilarity.

``` r
analysed <- recoverome::add_deviation(referenced, analysis_id = "antibiotic")
SummarizedExperiment::colData(analysed)[, c(
  "rec_antibiotic_deviation", "rec_antibiotic_deviation_status"
), drop = FALSE]
#> DataFrame with 3 rows and 2 columns
#>    rec_antibiotic_deviation rec_antibiotic_deviation_status
#>                   <numeric>                     <character>
#> s1                     0.00                        computed
#> s2                     0.05                        computed
#> s3                     0.40                        computed
```

The deviations are `0`, `0.05`, and `0.4` for `s1`, `s2`, and `s3`. The
baseline sample has zero self-deviation; this is descriptive similarity
over the selected features, not a recovery decision. Included samples
without a baseline receive `NA` and `missing_baseline`; excluded samples
receive `NA` and `excluded`. Neither case is assigned a fabricated
distance.

Calculate before removing baseline inputs. Once deviations exist,
filtering keeps the retained sample values and the original analysis
history. Reordering matches identities; it never refits the reference.
Repeated additions error, including identical calls. Use a new analysis
name for a different definition.

## Check current dependencies without rewriting history

``` r
recoverome::validate_recovery(analysed, analysis_id = "antibiotic")$summary
#> DataFrame with 1 row and 8 columns
#>   analysis_id structural_valid validation_complete dependencies sample_scope
#>   <character>        <logical>           <logical>  <character>  <character>
#> 1  antibiotic             TRUE                TRUE    unchanged         same
#>   feature_scope n_registered n_retained
#>     <character>    <integer>  <integer>
#> 1          same            3          3

# A saved deviation keeps its value even when current measurements change.
changed <- analysed
SummarizedExperiment::assay(changed, "counts")[, "s3"] <- c(50L, 50L)
changed_report <- recoverome::validate_recovery(changed, analysis_id = "antibiotic")
changed_report$summary
#> DataFrame with 1 row and 8 columns
#>   analysis_id structural_valid validation_complete dependencies sample_scope
#>   <character>        <logical>           <logical>  <character>  <character>
#> 1  antibiotic             TRUE                TRUE      changed         same
#>   feature_scope n_registered n_retained
#>     <character>    <integer>  <integer>
#> 1          same            3          3
```

The original analysis has unchanged dependencies. In `changed`, the
stored `s3` deviation is still `0.4`, but the report identifies its
modified input. The comparison is complete even though a change was
found. By contrast, removing a required baseline or selected feature
leaves its comparison unavailable and validation incomplete. A subset
retains its historical meaning; validation does not silently recalculate
it.

Read `structural_valid`, `validation_complete` and `dependencies`
together. `deviation_status = "computed"` records a past calculation,
not present validity. See the
[vignette](https://xec-cm.github.io/recoverome/articles/recoverome.html)
for filtering and output edits, and the [diagnostic
guide](https://github.com/xec-cm/recoverome/blob/devel/dev/analytical-validation.md)
for supported codes and detection boundaries.

## Attach observed recovery outcomes

This seven-sample example uses one explicit baseline and six follow-up
visits. The rule below is illustrative, not a recommended biological
threshold; all four parameters must be supplied and justified for an
analysis.

``` r
data("recovery_examples", package = "recoverome")
example_data <- recovery_examples$observed_recovery
tse <- TreeSummarizedExperiment::TreeSummarizedExperiment(
  assays = list(counts = example_data$counts),
  colData = S4Vectors::DataFrame(example_data$col_data)
)
tse <- recoverome::setup_recovery(
  tse,
  analysis_id = "observed",
  episodes = example_data$episodes,
  events = example_data$events,
  time_col = example_data$time_col,
  time_unit = example_data$time_unit,
  time_origin = example_data$time_origin
)
tse <- recoverome::add_reference(tse, "observed", reference = "b1", assay = "counts")
tse <- recoverome::add_deviation(tse, "observed")
rule <- list(threshold = 0.25, persistence = 4, max_gap = 3, horizon = 10)
recovered <- recoverome::add_recovery(tse, "observed", rule)
outcome <- S4Vectors::metadata(recovered)$recoverome$analyses$observed$recovery
outcome$episodes[, c("status", "candidate_time", "confirmation_time", "rebound_time", "coverage")]
#> DataFrame with 1 row and 5 columns
#>             status candidate_time confirmation_time rebound_time
#>        <character>      <numeric>         <numeric>    <numeric>
#> 1 confirmed_return              2                 6            8
#>          coverage
#>       <character>
#> 1 reaches_horizon
```

The candidate return is observed at relative day 2 and confirmed at day
6. A rebound at day 8 preserves that first confirmation. Coverage
reaches the 10-day horizon; it does not establish uninterrupted recovery
between visits. Outcomes belong to episodes and are stored in metadata,
with supporting sample IDs in `outcome$evidence`. No recovery columns
are added to `colData()`.

`add_recovery()` requires the complete realized deviation scope and
unchanged parent dependencies. Calculate before filtering. Later subsets
retain the original outcome; `validate_recovery()` reports missing
inputs and any independently detectable changes without reclassifying
it. See the
[vignette](https://xec-cm.github.io/recoverome/articles/recoverome.html)
and the [observed recovery
guide](https://github.com/xec-cm/recoverome/blob/devel/dev/observed-recovery.md).

## Plot observations and saved evidence

``` r
recoverome::plot_recovery(recovered[, colnames(recovered) != "s3"], "observed", scope = "historical")
```

<img src="man/figures/README-plot-recovery-1.png" alt="Saved deviations and confirmation after removing an intermediate supporting visit."  />

Points retain registered times and saved deviations. The separate
evidence rail preserves first return, candidate, confirmation and
rebound. Hollow marks and dashed supporting spans mean required
observation IDs are missing from the current TSE, including intermediate
confirmation visits. They do not express uncertain timing. Original
visit gaps and missing follow-up remain visible. The shaded detection
window is declared by the rule, not a confidence interval.

The function returns an ordinary unprinted `ggplot2` object; use
`+ ggplot2::labs(title = "My analysis")` or `+ ggplot2::theme_bw()` to
customize it. Select episodes in display order with
`episodes = c("episode_1")`. `ggplot2` is a runtime dependency used to
construct these customizable layers.

## Extract saved results

``` r
results <- recoverome::recovery_results(recovered, "observed")
results[, c("episode_id", "result_state", "confirmation_time", "dependencies")]
#> DataFrame with 1 row and 4 columns
#>    episode_id result_state confirmation_time dependencies
#>   <character>  <character>         <numeric>  <character>
#> 1   episode_1    available                 6    unchanged

filtered <- recovered[, colnames(recovered) != "s3"]
samples <- recoverome::recovery_results(
  filtered, "observed", level = "sample", scope = "historical"
)
as.data.frame(samples)[, c("sample_id", "relative_time", "result_state", "deviation")]
#>   sample_id relative_time result_state deviation
#> 1        b1            -2    available     0.000
#> 2        s1             0    available     0.750
#> 3        s2             2    available     0.250
#> 4        s3             4      removed        NA
#> 5        s4             6    available     0.125
#> 6        s5             8    available     0.500
#> 7        s6            10    available     0.125
```

The removed day-4 sample has `result_state = "removed"` and no
reconstructed value. Episode extraction still returns confirmation at
day 6. Tables follow registration order and use saved times even if
current annotations have changed. `scope = "current"` selects retained
original samples or episodes with retained included samples;
`"historical"` keeps the full registered scope.

The returned `S4Vectors::DataFrame` has atomic columns. Its validation
fields describe the selected analysis, not each row. Full diagnostics,
definitions and supporting IDs are in
`S4Vectors::metadata(results)$recoverome_view`. That metadata is a
snapshot: call `recovery_results()` again to refresh it against a TSE.
Conversion to a data.frame or tibble preserves the columns but need not
preserve this context. See the [extraction
guide](https://github.com/xec-cm/recoverome/blob/devel/dev/result-extraction.md).

## Available and planned workflow

| Function | Status | Responsibility |
|:---|:---|:---|
| `setup_recovery()` | Available | Register a named analysis, episodes, and events. |
| `add_reference()` | Available | Attach personal reference profiles, support and input provenance. |
| `add_deviation()` | Available | Attach sample deviations and provenance from the fixed reference. |
| `add_recovery()` | Available | Attach observed episode outcomes under an explicit recovery rule. |
| `recovery_results()` | Available | Extract saved results with availability and historical context. |
| `plot_recovery()` | Available | Display observations, saved evidence, gaps and follow-up. |
| `validate_recovery()` | Available | Diagnose analytical dependencies and historical scope. |

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

Remaining MVP work is tracked in the [development
project](https://github.com/users/xec-cm/projects/10). No benchmark
performance or statistical guarantees are claimed for this version.

See [CONTRIBUTING](.github/CONTRIBUTING.md) for local checks and
contribution guidelines. Please use the [issue
tracker](https://github.com/xec-cm/recoverome/issues) to discuss designs
or report a reproducible problem.

Maintainer: Francesc Catala-Moll
([ORCID](https://orcid.org/0000-0002-2354-8648)),
<fcatala@irsicaixa.es>.
