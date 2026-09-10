# Maintenance and execution-cost assessment

Issue #42 shares reference-definition and support-column predicates between
calculation and diagnostic parsing. It changes neither analytical methods nor
public schemas, numerical results, error classes or historical records.

## Maintenance decisions

The shared predicates expose individual field readiness. `validate_recovery()`
can therefore continue comparing readable sources when another definition field
is malformed. `add_deviation()` keeps its first-error policy and its existing
order of checks. The validator's additional finite-or-NA support-time check is
intentionally separate: applying it earlier during calculation would change the
reported error component. Reference membership/order, profile relationships,
provenance interpretation and hash comparisons retain their existing policies.
No generic validation framework or additional runtime dependency is introduced.

The registration error helper now requires the intended condition class and
component, while retaining input-preservation assertions. Every ID field still
has a dispatch check; a representative field covers the complete invalid-ID
matrix. Both event endpoints retain finite/order tests, while all invalid time
classes exercise the column-data and event-table paths without repeating the
same matrix for both endpoints. This removes 16 repeated ID combinations and
nine repeated endpoint combinations; it does not remove identity, filtering,
exclusion, overflow, tree or numerical cases. A missing required `assay` argument
remains an R error with its specific message rather than being mistaken for a
recoverome condition. Two paired regressions protect the distinct calculation
and diagnostic policies.

There is no target for test count, helper count or coverage. A stronger assertion
can increase the number of expectations even after duplicate scenarios are
removed. This internal refactor does not require a user-facing NEWS entry.

## Measurement design

The optional `run.R` script stays outside package tests and the source archive.
Run it explicitly from the package checkout with `Rscript --vanilla`. It requires
the existing development dependencies and, only for the disk case, `HDF5Array`.
Install profiling dependencies in a development library, not package Imports.

Two deterministic sparse-like count matrices are used: 200 features x 100 samples
and 2,000 features x 400 samples. They contain about 5% nonzero entries, with one
positive feature in every sample. Ten visits form each episode, with two baseline
visits; episodes belong to separate subjects. These inputs exercise storage and
execution costs, not scientific plausibility or algorithm qualification.

Each matrix is represented as an ordinary double matrix, a `dgCMatrix`, and an
actual `HDF5Matrix` backed by a temporary HDF5 file. HDF5 uses chunks of all
features x ten samples and compression level six. Input checksums must match
across representations. File creation, conversion and reference preparation are
outside the per-operation timings. The `workflow` operation independently
includes registration, reference, deviation and observed-outcome calculation.

Operations are measured separately:

- `load`: deserialize the saved input TSE. HDF5 restores a descriptor, not all
  abundance values; this is deliberately separate from assay materialization.
- `materialize`: access the assay and convert it to a dense matrix.
- `workflow`, `validate`, and sample/episode extraction: full public calls.
- Four plot operations: public preparation plus `ggplotGrob()` layout construction,
  not just allocation of a lazy ggplot object. Device-specific rasterization and
  image encoding are excluded.

There are three uninstrumented elapsed-time observations per operation. The first
is labelled `first_measured`, not cold I/O: setup already used the assay, and OS,
HDF5, method and font caches are not cleared. Later observations represent repeat
access within that same R process. Each backend/size starts a new R process.
`pkgload::load_all()` loads the checkout before measurement; startup is excluded and the reported heap includes
that development environment.

A separate fourth call measures R allocations using `Rprofmem()` and resets GC
high-water counters first. Its metrics repeat across the three timing rows;
**they are one memory observation, not three memory replicates**. Allocated bytes
are cumulative allocations, not simultaneous live memory. `heap_before_mib` and
`heap_high_water_mib` include the loaded development environment and retained
fixture. The latter sums the maxima for Ncells/Vcells, which need not occur
simultaneously. It is a coarse heap proxy, **not RSS or native HDF5 cache memory**.
Values are MiB; small elapsed times may fall below the clock's resolution.

## Reproduction

Use the source immediately before this issue (`7764a13`) for the baseline test
suite and this PR's source for the revised suite. Tests run twice in a fresh R
process per source; each second run reuses that process. Profiling jobs should run
serially without other heavy R work. Record the installed versions and machine;
these bounded observations are not a general speed or memory guarantee.

```sh
Rscript --vanilla dev/performance/run.R tests /path/to/baseline 7764a13 before.csv
Rscript --vanilla dev/performance/run.R tests . issue42 after.csv

for backend in dense sparse hdf5; do
  Rscript --vanilla dev/performance/run.R workflow "$backend" 200 100 "$backend-200.csv"
  Rscript --vanilla dev/performance/run.R workflow "$backend" 2000 400 "$backend-2000.csv"
done
```

Each workflow command writes a CSV, a session-information text file and an RDS of
validation/sample/episode values for cross-backend equivalence checking. Keep
transient files outside the repository. The committed results consolidate the
CSVs and document the environment; raw output tables need not be duplicated in
git. Reference fingerprints/timestamps are not claimed to be identical across
new analysis runs; compare the resulting values and diagnostic reports.

## Recorded observations

The [workflow CSV](results/workflow.csv) contains all 180 timing rows (six
backend/size runs, ten operations, three observations). The
[test CSV](results/tests.csv) contains both complete runs per source. The
[environment record](results/environment.txt) identifies the source revisions,
script, R 4.6.1, package versions and Apple M4 machine with 32 GiB RAM. Runs were
serial on 2026-09-10; background machine activity was not controlled.

Validation reports and sample/episode result tables agree across dense, sparse
and HDF5 representations at both sizes (`all.equal()` on each saved result
list). This checks actual outputs in addition to equal generated-input hashes.
It is an equivalence check for these fixtures, not general backend certification.
Reproduce that comparison on the RDS files emitted by the commands above:

```r
for (size in c(200, 2000)) {
  results <- lapply(c("dense", "sparse", "hdf5"), function(backend) {
    readRDS(paste0(backend, "-", size, ".csv.results.rds"))
  })
  stopifnot(isTRUE(all.equal(results[[1L]], results[[2L]])),
            isTRUE(all.equal(results[[1L]], results[[3L]])))
}
```

The revised test suite passed 3,207 expectations with no failures, warnings or
skips in both runs; the baseline passed 3,095. The additional expectations check
error classes/components rather than adding redundant scenarios. Baseline times
were 74.005 and 101.039 seconds; revised times were 80.160 and 73.226 seconds.
The variation does not establish a general speed improvement or regression.

For the 200-feature, 100-sample fixture, the full workflow's median elapsed time
was 0.507 s (dense), 0.402 s (sparse), and 1.083 s (HDF5). Its cumulative R
allocations were 12.25, 12.30, and 14.94 MiB respectively.

The table below describes the 2,000-feature, 400-sample fixture (40 episodes).
Each cell is **median elapsed seconds / cumulative allocated MiB**; the second
quantity comes from the separate allocation run, not the timing observations.

| Operation | Dense | Sparse | HDF5 |
|:----------|------:|-------:|-----:|
| `load` | 0.003 / 6.16 | 0.001 / 0.52 | 0.001 / 0.03 |
| `materialize` | 0.003 / 0.01 | 0.003 / 6.11 | 0.011 / 6.19 |
| `workflow` | 1.421 / 285.78 | 1.543 / 286.94 | 4.717 / 345.27 |
| `validate` | 0.240 / 99.36 | 0.293 / 99.96 | 4.381 / 151.19 |
| `extract_samples` | 0.257 / 99.76 | 0.328 / 100.37 | 2.964 / 151.60 |
| `extract_episodes` | 0.267 / 99.64 | 0.329 / 100.25 | 2.486 / 151.48 |
| `plot_recovery` | 1.021 / 107.65 | 1.015 / 108.25 | 3.531 / 159.48 |
| `plot_reference` | 0.890 / 106.36 | 0.965 / 106.97 | 2.910 / 158.20 |
| `plot_sampling` | 0.969 / 108.26 | 1.218 / 108.87 | 3.169 / 160.10 |
| `plot_overview` | 0.476 / 101.86 | 0.573 / 102.47 | 2.219 / 153.70 |

A dense copy of this assay occupies about 6.1 MiB. Explicit sparse/HDF5
materialization allocates approximately that amount; converting an already dense
assay largely reuses it. HDF5 deserialization restores a small descriptor, so its
`load` time must not be interpreted as reading the full assay from disk.

Storage sparsity does not translate into equally small cumulative analytical
allocations here: the workflow allocates about 286 MiB for both dense and sparse
inputs. HDF5 validation, extraction and plotting remain more expensive even
though the file was accessed during preparation. These operations include source
and historical-dependency checks; they are not merely formatting saved tables.
The measurements do not isolate the cause of every allocation or disk access.
In particular, the separately measured HDF5 validation and extraction times vary
enough that they must not be read as additive stage costs.

The recorded heap high-water proxies span roughly 531–983 MiB across operations.
They include a large loaded development environment; they are not incremental
requirements for a user session and do not measure native HDF5 memory. Neither
this quantity nor cumulative allocations establishes a memory leak.

## Bounded follow-up opportunities

- Investigate copies and repeated source reads in reference/dependency checking
  with a call-level allocation/I/O profile. Preserve source-change detection and
  historical scope; these observations do not justify caching or skipping checks.
- Assess genuinely larger studies in separate installed-package processes,
  recording process RSS, disk/cache conditions and HDF5 chunk layouts. The two
  measured sizes do not establish out-of-core scalability or a safe maximum size.
- If rendering becomes a user bottleneck, separate historical validation,
  plot-data preparation, layout and device output before choosing an optimization.

These are measured-cost follow-ups, not optimizations implemented in this issue.
The current PR retains the method and public behavior while making their checks
more maintainable and their costs reproducible.
