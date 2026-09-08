# Architecture contract

Status: design contract for the experimental recoverome 0.1.0 scaffold.
No recovery analysis functions are implemented in this version. The decisions
below guide subsequent implementation; illustrative schemas are not stable
public interfaces.

## Purpose and scope

recoverome is intended to attach explicit recovery analyses to longitudinal
microbiome data after known perturbations. The first implementation should
establish data identity, analysis scope, and provenance before analytical
methods are added.

The initial public interface is limited to seven planned functions:

| Function | Contract |
|:---------|:---------|
| `setup_recovery()` | Register a named analysis and its episodes/events. |
| `add_reference()` | Add a reference definition and its realized scope. |
| `add_deviation()` | Add sample-level deviations from that reference. |
| `add_recovery()` | Add outcomes under a recorded recovery rule. |
| `recovery_results()` | Extract the requested results with their scope. |
| `plot_recovery()` | Display data and analysis annotations. |
| `validate_recovery()` | Diagnose consistency and scope mismatches. |

Statistical model fitting is a future layer outside these seven functions.
Do not introduce exported fitting stubs, unvalidated estimators, synthetic
benchmark claims, or placeholder result objects into the scaffold.

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

Specific input schemas, accepted assays, distance definitions, and tree
requirements must be documented and tested when their consuming functions are
implemented. They must not be implied to work before that point.

## Storage

The intended metadata namespace is:

```text
metadata(tse)$recoverome
  analyses
    <analysis_id>
      episodes
      events
      reference
      provenance
      ... documented analysis records added by implemented functions
```

Each analysis is named. Episodes and events are explicit records, not values
reconstructed later from a plot or from sample order. Reference records retain
both the user's definition and the identities of the eligible data actually
used. Provenance captures the information needed to interpret or reproduce the
analysis, including the original sample and feature scope.

Sample-level results belong in `colData(tse)` with the prefix
`rec_<analysis>_`, where `<analysis>` is the named analysis ID. For example,
analysis `antibiotic` can own `rec_antibiotic_deviation`. Analysis IDs must be
simple, stable identifiers. Validate names and collisions so separate analyses
cannot overwrite each other or collide with user columns.

Keep one authoritative representation of each result. If an extraction method
creates a convenient table, it should derive that view from the stored record
rather than maintain an independently mutable copy.

## Filtering and historical scope

Standard TSE subsetting selects assays and sample annotations. Historical
analysis metadata must retain the scope of the analysis as originally run.
Subsetting must not silently rebuild a reference, recalculate deviations,
reclassify an episode, or refit a model.

The validator must distinguish current object scope from original analysis
scope. Examples requiring explicit diagnostics include:

- Removal of a sample used to estimate a reference.
- Removal of a visit used to assess persistence or an episode endpoint.
- Removal or alteration of features used to compute a deviation.
- Changes to an assay or time metadata on which the analysis depended.
- Broken sample, subject, event, or episode references.

A subset can carry valid historical records without being a fresh analysis of
that subset. Extraction and plotting must identify this distinction and must
not silently reinterpret historical outcomes. The exact diagnostic severity
for each operation will be specified with its implementation.

Recomputation is explicit. It should use a new named analysis or a documented
replacement operation that makes invalidation of dependent results visible.
Dependent records must not survive upstream changes as if still current.

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

## Implementation sequence

1. Define validated schemas, stable identities, and named-analysis storage.
2. Implement setup and reference attachment with meaningful validation.
3. Add a documented deviation method and provenance requirements.
4. Implement a prespecified observation-based recovery rule.
5. Add extraction and plotting that respect historical scope.
6. Validate behavior under filtering and upstream changes.
7. Design statistical fitting only after these contracts are usable.

Introduce runtime dependencies when an implemented feature uses them. Tests
should verify meaningful behavior and contract failures rather than preserve
placeholder output. Document implemented behavior and planned work separately.
