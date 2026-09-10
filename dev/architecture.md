# Architecture contract

Status: the experimental development version implements named analysis
registration through `setup_recovery()` and registration plus analytical
dependency diagnostics through `validate_recovery()`. `add_reference()` attaches
explicit personal baseline profiles and `add_deviation()` records sample
dissimilarities under [RFC 002](rfcs/002-personal-baseline-deviation.md).
`add_recovery()` attaches observed episode outcomes under
[RFC 003](rfcs/003-observed-recovery.md). `recovery_results()` extracts sample and
episode tables under [RFC 004](rfcs/004-result-extraction-plotting.md);
see [result extraction](https://xec-cm.github.io/recoverome/articles/history-and-validation.html). `plot_recovery()` displays saved
observations and evidence.

[RFC 001](rfcs/001-registration-validation.md) is the accepted registration and
validation contract for issues #6--#8. Registration and its validator are
implemented; [integration evidence](README.md) records the tested
preservation and historical-scope behavior. Later
analytical stages need their own accepted RFCs.

`recovery_sensitivity()` and `plot_sensitivity()` implement the rule-comparison
part of accepted [RFC 005](rfcs/005-sensitivity-diagnostic-plots.md). They return
standalone snapshot tables and plots without writing scenarios back to the TSE.
`plot_reference()`, `plot_sampling()` and `plot_recovery_overview()` implement
the diagnostic views in the same contract.

## Purpose and scope

recoverome is intended to attach explicit recovery analyses to longitudinal
microbiome data after known perturbations. Registration establishes data
identity, analysis scope, and provenance before analytical methods are added.

The original seven-function workflow is extended by rule sensitivity and
three diagnostic plots:

| Function | Status | Contract |
|:---------|:-------|:---------|
| `setup_recovery()` | Available | Register a named analysis and its episodes/events. |
| `add_reference()` | Available | Attach personal reference profiles, support and realized scope. |
| `add_deviation()` | Available | Add sample-level deviations from the fixed reference. |
| `add_recovery()` | Available | Attach observed episode outcomes under a recorded recovery rule. |
| `recovery_results()` | Available | Extract saved tables, availability and historical context. |
| `plot_recovery()` | Available | Display saved observations, evidence and follow-up. |
| `recovery_sensitivity()` | Available | Compare explicit rules without changing the saved analysis. |
| `plot_sensitivity()` | Available | Display all requested scenario and episode outcomes. |
| `plot_reference()` | Available | Inspect recorded baseline support and available distances. |
| `plot_sampling()` | Available | Inspect registered visits, events and original observation gaps. |
| `plot_recovery_overview()` | Available | Compare saved episode milestones and evidence availability. |
| `validate_recovery()` | Available | Diagnose analytical dependencies and historical scope. |

Statistical model fitting is a future layer outside these descriptive functions.
Do not introduce exported fitting stubs, unvalidated estimators, synthetic
benchmark claims, or placeholder result objects into the package.

## Container and identities

- Use `TreeSummarizedExperiment` as the analysis container.
- The setup/add functions take a TSE and return a TSE.
- Preserve assays, feature identities, sample identities, and unrelated
  metadata unless an explicit contract authorizes a change.
- Use supported accessors; never write directly to S4 slots.
- Treat sample IDs, subject IDs, episode IDs, and analysis IDs as distinct
  identities. Multiple episodes may belong to one subject.
- Validate identity uniqueness and referential integrity rather than relying
  on row position or implicit recycling.
- Record time units and event origins explicitly. Do not infer units from the
  size of a numeric value or equate a visit index with elapsed time.

Under RFC 001, sample IDs come from `colnames(tse)` and feature IDs from
`rownames(tse)`. Both must be unique and explicit. Literal `colData()` column
selectors supply subject, episode and numeric time. An episode value of `NA`
excludes a sample; otherwise it identifies exactly one declared episode.
Multiple episodes per subject are allowed. Each episode explicitly selects the
start or end boundary of a declared event as its origin. Numeric times require
an explicit unit and a coordinate-system description. No sample assignment,
calendar conversion or analytical eligibility is inferred at registration.

RFC 001 defines the registration input schemas. Accepted assays, distance
definitions and analytical tree requirements must be documented and tested
when their consuming functions are implemented. They must not be implied to
work before that point.

## Tidy interoperability

Tidy interoperability is an optional integration layer. TSE already inherits
from `SingleCellExperiment`; do not replace it with a plain SCE or introduce
a new public container solely to access `tidySingleCellExperiment` methods.
Core operations should remain usable without a tidy wrapper or dependency.

Before documenting a tidy operation as supported, verify that it preserves
the TSE class, tree links, sample identities, and analysis annotations. Tidy
filtering and mutation must follow the same historical-scope and invalidation
contracts as base subsetting and accessor-based edits. The bounded
[tidy interoperability assessment](tidy-interoperability.md) verifies optional
sample filtering, reordering and ordinary annotation mutation directly on TSE
with recorded adapter versions. Mutation loses `colData()` metadata and column
descriptors in the tested adapter and is unsupported when these must be preserved.
No tidy adapter is required for registration or the core workflow.

## Storage

The implemented registration namespace is:

```text
metadata(tse)$recoverome
  schema_version = 1L
  analyses
    <analysis_id>
      schema_version = 1L
      registration
        source_columns
        time_unit, time_origin
        samples                   # DataFrame of included sample metadata
      episodes, events            # normalized DataFrames
      scope
        sample_ids, feature_ids   # full original container scope
      owned_columns = character()
      provenance
        package_version, registered_at
```

Each analysis is named. Episodes and events are explicit records, not values
reconstructed later from a plot or from sample order. Registration stores the
consumed source-column bindings and a normalized snapshot of included sample
metadata. The full original scope also includes samples explicitly excluded
from the analysis. Provenance records the package version and UTC registration
time. The historical snapshot must not be edited as a second current data source.

Registration stores no assay values or fingerprints and creates no result
columns. Each analysis starts with an empty exact-name `owned_columns` manifest;
later result functions must extend ownership when they add sample columns.
No reference, deviation, or recovery records are preallocated at registration.
`add_reference()` adds its versioned record explicitly, retaining the definition,
realized baseline samples, episode support, profile matrix, dependencies and
provenance specified in RFC 002. It adds no sample result columns. The validator
checks supported reference, deviation and recovery records and their dependencies,
reporting unavailable historical comparisons separately from detected changes.
`add_deviation()` checks its own required reference dependencies before
creating the deviation and status columns. Its versioned metadata stores method,
column mapping, realized sample scope, source/result fingerprints and provenance.
The sample columns remain the sole authoritative deviation values; later
filtering preserves their original metadata scope. `add_recovery()` adds only
an episode-level `recovery` record, with rule, outcomes, evidence, dependencies
and provenance. It does not extend `owned_columns` or duplicate deviations.
See [observed recovery](https://xec-cm.github.io/recoverome/articles/history-and-validation.html) for the implemented storage.

Sample-level results belong in `colData(tse)` with the prefix
`rec_<analysis>_`, where `<analysis>` is the named analysis ID. For example,
analysis `antibiotic` can own `rec_antibiotic_deviation`. RFC 001 requires analysis
IDs to match `^[a-z][a-z0-9]*$`; underscores are excluded to prevent overlapping
prefixes. An existing analysis ID or existing column under its proposed prefix
blocks registration. There is no implicit overwrite or replacement operation.

Keep one authoritative representation of each result. If an extraction method
creates a convenient table, it should derive that view from the stored record
rather than maintain an independently mutable copy.

## Filtering and historical scope

Standard TSE subsetting selects assays and sample annotations. Historical
analysis metadata must retain the scope of the analysis as originally run.
Subsetting must not silently rebuild a reference, recalculate deviations,
reclassify an episode, or refit a model.

The validator distinguishes current object scope from original analysis scope.
It diagnoses removed baseline inputs and computed samples, missing selected
features, changes to consumed assay values or registration metadata, inconsistent
parent records and altered authoritative deviations. Broken sample, subject,
event and episode references retain their registration diagnostics. Recovery
validation also checks episode outcomes, evidence and their complete parent chain
without re-running the observed rule.

A subset can carry valid historical records without being a fresh analysis of
that subset. Extraction and plotting must identify this distinction and must
not silently reinterpret historical outcomes. The exact diagnostic severity
for each operation will be specified with its implementation.

Recomputation is explicit. It should use a new named analysis or a documented
replacement operation that makes invalidation of dependent results visible.
Dependent records must not survive upstream changes as if still current.

The validator returns a base list containing a versioned summary and diagnostics
as `S4Vectors::DataFrame` objects. Structural validity,
completion of checks, source-metadata changes and current sample/feature scope
are separate report fields. Removing samples preserves historical episode
records; changing a retained sample's consumed source metadata will produce a
dependency finding. An analysis containing registration only does not require
assay access. Supported analytical stages add selected-block source and stored
result comparisons using the RFC 002 fingerprints and RFC 003 recovery records.
Unknown schemas remain incompletely checked. See RFC 001 for the report schema and
[analytical validation](https://xec-cm.github.io/recoverome/articles/history-and-validation.html) for the additional diagnostics
and detection boundaries.

## Analytical boundaries

Reference estimation, deviation measurement, and recovery classification are
separate stages. A reference distribution is not automatically an equivalence
margin, and a nonsignificant baseline comparison is not proof of recovery.

A sustained-recovery rule must state its observational requirements, including
time horizon, persistence duration, and handling of gaps. When observations
only establish an interval, results must not invent an exact event time.
Continuous behavior between visits requires an explicit model or assumption.

No observed recovery before follow-up ends is different from evidence of
permanent non-recovery. Uncertainty estimation, interval censoring, group
comparisons, and model fitting require separately specified estimands and
validation. The first storage contracts must leave room to represent those
distinctions without claiming those methods already exist.

## Current implementation and next work

All seven original API functions, including plotting, are implemented. M6 improves
onboarding and maintenance; M7 qualifies the current descriptive method and adds
explicit rule sensitivity; M8 adds diagnostics and external user evaluation.
The [development project](https://github.com/users/xec-cm/projects/10) owns the
backlog. Rule sensitivity and the diagnostic plots accepted in RFC 005 are
implemented. Inference, new distance
estimators and automatic calibration require separate decisions.

Introduce runtime dependencies when an implemented feature uses them. Tests
should verify meaningful behavior and contract failures rather than preserve
placeholder output. Document implemented behavior and planned work separately.
