# Optional tidy interoperability

The bounded assessment in issue #19 verifies sample operations dispatched by
`tidySingleCellExperiment` directly on an existing `TreeSummarizedExperiment`
(TSE). No conversion, new container, public API or mandatory dependency is added.
`tidySingleCellExperiment` belongs to the [tidyomics ecosystem][ecosystem].
Its [documentation][adapter] describes the sample annotation view; the tested
installed methods subset the original object or replace its `colData()`.
Inheritance alone is not the evidence: the executable checks compare the results
with base TSE subsetting and public accessor edits.

## Assessed operations and limits

Support below means the stated operation preserved the tested contracts with the
recorded versions. It is not a promise for every tidy verb, argument or annotation
type. The fixtures have atomic sample annotations, including a factor and missing
values, two assays, feature annotations, both trees with deliberately permuted tip
orders, and two named analyses. One analysis contains registration, reference,
deviation and recovery records; the other contains registration only.

| Operation on the existing TSE | Outcome |
|:-----------------------------|:--------|
| `dplyr::filter(tse, .cell %in% ids)` | Preserves class, assays, annotations, trees, links and historical records, including excluded-only and empty sample selections. |
| `dplyr::filter(tse, episode_id == "e1")` | Matches base selection of the included samples in that episode; missing predicates are dropped by the adapter. |
| `dplyr::arrange(tse, dplyr::desc(.cell))` | Reorders samples and their links together. Extraction continues to use original registration order. |
| `dplyr::mutate(tse, note = paste0("batch-", batch))` | Preserves the tested container and adds the annotation **only within the ordinary atomic-annotation case described below**. |
| `dplyr::mutate(tse, time = time + 1)` | Matches an accessor edit: consumed metadata changes are diagnosed, and extracted times still use the saved registration. This does not update the historical analysis. |
| `dplyr::mutate(tse, rec_antibiotic_deviation = 0)` | Matches an invalid accessor edit: validation reports inconsistent results and extraction errors. The other named analysis remains unaffected. |
| `dplyr::filter(tse, taxonomy == "taxon-a")` | Unsupported: row annotations are not in this sample view, and the tested expression errors. Use TSE row subsetting for features. |
| `dplyr::mutate(tse, .cell = ...)` | Unsupported: the sample identity column is view-only and the adapter rejects mutation. |
| Mutation when `metadata(colData(tse))` or `mcols(colData(tse))` contains information | **Unsupported for preservation:** the adapter rebuilds `colData()` through an ordinary table and loses that annotation metadata and column descriptors, even when adding an unrelated column. TSE-level metadata and recoverome records survive. |

For mutation, the positive evidence covers atomic annotation columns with empty
`metadata(colData(tse))` and absent `mcols(colData(tse))` column descriptors.
Column descriptors are lost even when the DataFrame-level metadata is empty. Do not generalize it to list-like columns, specialized
S4 vectors, reduced-dimension annotations, grouped data, joins or reshaping: these
were not assessed. Use public accessors when annotation metadata or column descriptors must survive:

```r
annotations <- SummarizedExperiment::colData(tse)
annotations$note <- "reviewed"
SummarizedExperiment::colData(tse) <- annotations
```

The `.cell` column in this adapter is a view of `colnames(tse)`, even when the
samples are microbiome visits rather than cells. No cell-based interpretation of
the recovery analysis is introduced. This assessment does not cover simultaneous
loading of multiple tidy adapters or their method-dispatch interactions.
`tidySummarizedExperiment` and the `tidyomics` meta-package were not installed or
executed. Their capabilities remain unverified here; the [tidySummarizedExperiment
project][tidyse] is a separate adapter, not an interchangeable tested backend.

## History and diagnostics

The optional tests use the same bundled `recovery_examples$repeated_episodes`
fixture as the base TSE integration tests, including its excluded sixth sample.
They compare both trees and link tables, identities, every assay, row/sample
annotations, all TSE metadata and both named records. Link node numbers are also
asserted independently against the deliberately permuted trees.

Filtering preserves the original reference, deviations and episode outcomes. It
never recomputes them from retained observations. Removing baseline and follow-up
samples produces the same missing-input diagnostics as base selection, with
`dependencies = "not_checked"` and incomplete analytical validation. An excluded
sample alone does not make an episode current. Historical episode rows and their
saved outcomes remain available even when no included observations remain.

Reordering leaves dependencies unchanged. A consumed-time edit produces changed
dependency findings for each analysis using that column, while extraction retains
the original coordinates. An owned-deviation edit corrupts its saved result;
extraction must fail rather than present the modified values as a coherent view.
The assessment compares complete validation reports and sample/episode views in
both current and historical scope, including their metadata. These checks follow
[the architecture](architecture.md) and [RFC 004](rfcs/004-result-extraction-plotting.md).

For the completed `recovered` TSE built in the README, a sample-only pipeline is:

```r
# Optional package: load its namespace to register methods on the existing TSE.
stopifnot(requireNamespace("tidySingleCellExperiment", quietly = TRUE))
selected <- recovered |>
  dplyr::filter(.cell != "s3") |>
  dplyr::arrange(dplyr::desc(.cell))
recoverome::validate_recovery(selected)
recoverome::recovery_results(selected, "observed", scope = "historical")
```

Keep the TSE as the authoritative analysis. For downstream table operations, use
`as.data.frame(recovery_results(...))` and optionally a tibble conversion, keeping
IDs and validation flags as columns. Table conversions need not preserve the
contextual metadata; see [result extraction](https://xec-cm.github.io/recoverome/articles/history-and-validation.html).

## Reproduce the evidence

Run from the repository root in separate clean R sessions:

```sh
Rscript --vanilla dev/check-tidy.R
Rscript --vanilla dev/check-without-tidy.R
```

`check-tidy.R` uses existing development dependencies `pkgload` and `testthat`,
and the optional adapter plus `dplyr` to exercise actual methods. It prints package
versions and runs [the bounded tests](tests/test-tidy.R). Missing dependencies
cause an explicit failure; the checks never skip the whole assessment. The script
is excluded from the built package with the other `dev/` files. No new `Imports`,
`Suggests`, dependency installation, or CI requirement is introduced for this
optional development assessment. Run it explicitly when changing the adapter
version or the contracts it exercises; ordinary package CI does not run it.

`check-without-tidy.R` creates a temporary symlink library excluding all three
adapters (`tidySingleCellExperiment`, `tidySummarizedExperiment`, `tidyomics`) and
starts a new `Rscript --vanilla` process with isolated library environment values.
It checks that none can be loaded, runs the full package test suite and
`dev/check-package.R`, then checks absence again. The ordinary suite exercises
setup, every implemented add stage, extraction and validation. R's base library
is checked before launching the child so it cannot reintroduce an adapter.
Installed packages are never moved or modified; the temporary symlinks are
removed after the child finishes. This local check needs a filesystem supporting
symlinks, the existing package/check dependencies and Pandoc for the vignette.

The observed run used macOS arm64 on 2026-09-10:

| Component | Version |
|:----------|:--------|
| R | 4.6.1 |
| recoverome development source | 0.1.0, based on `devel` commit `39e7f06` |
| TreeSummarizedExperiment | 2.20.0 |
| SingleCellExperiment | 1.34.0 |
| SummarizedExperiment | 1.42.0 |
| S4Vectors | 0.50.1 |
| tidySingleCellExperiment | 1.22.0, Bioconductor 3.23, upstream commit `212cc68` |
| dplyr | 1.2.1 |

The optional assessment completed **175 assertions, zero failures, warnings or
skips**. The failures of unsupported operations and annotation-metadata loss are
explicit observations asserted by this version-specific assessment. If a later
adapter fixes them, reassess and revise the evidence instead of preserving the
limitation as desired behavior.

The isolated run completed **2,673 core assertions with zero failures, warnings
or skips**, followed by **R CMD check: 0 errors, 0 warnings, 0 notes**. The child
confirmed that all three optional adapters remained unavailable after checking.

[ecosystem]: https://github.com/tidyomics/tidyomics
[adapter]: https://tidyomics.github.io/tidySingleCellExperiment/
[tidyse]: https://github.com/tidyomics/tidySummarizedExperiment
