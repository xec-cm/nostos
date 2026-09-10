# Result extraction

Issue [#17](https://github.com/xec-cm/recoverome/issues/17) implements the
extraction portion of accepted [RFC 004](rfcs/004-result-extraction-plotting.md).
Plotting and optional tidy operations on the TSE remain separate issues.
No estimator, reference or recovery rule changes here.

## Public operation

```r
recovery_results(tse, analysis_id, level = "episode", scope = "current")
```

The analysis ID is required and selects exactly one analysis. Both selectors
require exact scalar strings. The operation validates that analysis once,
projects its saved records and returns an ordinary `S4Vectors::DataFrame`.
It preserves the TSE, trees, other analyses and unrelated metadata. Validation
can read relevant assay blocks to compare fingerprints; extraction never
refits, recalculates or repairs a result.

Rows follow original registration order. Sample views use the full original
sample scope, including exclusions; episode views use registered episode order.
Current sample scope retains original IDs still present. Current episode scope
requires at least one retained originally included sample. Historical scope
keeps every original row. Additions are not enrolled and produce one
`recoverome_warning_scope` condition with complete `sample_ids`, `feature_ids`
and their union in `ids`.

## Columns and availability

Both levels start with `analysis_id`, `view_scope`, `current_present`,
`result_state`, `structural_valid`, `validation_complete` and `dependencies`.
The validation fields repeat the selected-analysis summary. They describe the
whole analysis, including stages not supplying the primary table, rather than
certifying individual rows.

| Level | Appended columns |
|:------|:-----------------|
| Sample | `sample_id`, `subject_id`, `episode_id`, `time`, `relative_time`, `included`, `is_reference`, `deviation`, `deviation_status` |
| Episode | `episode_id`, `subject_id`, `reference_support`, `n_baseline_samples`, `n_baseline_times`, `baseline_diameter`, `status`, `reason`, `coverage`, `first_perturbation_time`, `first_return_time`, `candidate_time`, `confirmation_time`, `rebound_time`, `last_observed_time`, `n_window_visits` |

Identity/status fields are character, flags logical, counts integer and times,
deviations and baseline diameter double. All columns are atomic. Empty views
retain the same types, names and context. Saved included-sample annotations
and saved origin events supply all sample coordinates. Excluded samples have
NA subject, episode and time, including when current colData contains values.

| Saved state | Sample `result_state` | Episode `result_state` |
|:------------|:----------------------|:-----------------------|
| No relevant stage | `not_computed` | `not_computed` |
| Realized deviation row is retained | `available`, including missing-baseline and excluded statuses | Determined by presence of recovery |
| Realized deviation row is removed | `removed`, deviation and status both NA | Still `available` if a recovery record exists |
| Sample was never in realized deviation scope | `not_computed` | Determined by presence of recovery |
| Recovery is stored but not evaluable | Determined by deviation availability | `available`, with the original reason |

Reference-only episode views expose support and counts before recovery.
An absent reference produces typed NA; an explicit empty baseline preserves
`missing_baseline` and zero counts. Evidence and historical outcomes survive
filtering. Hashes do not reconstruct removed sample values.

## Context schema

`S4Vectors::metadata(view)$recoverome_view` is a plain list:

- `schema_version = 1L` and `selection = list(analysis_id, level, scope)`.
- `validation`: the complete fresh selected-analysis report, including global
  findings, scope states, diagnostic severities and offending IDs.
- `registration`: saved `source_columns`, `time_unit`, `time_origin`, `episodes`
  and `events`. These include the original origin and blocking-event context.
- `scopes$registration`: the original sample and feature IDs. Each interpreted
  analytical stage has `sample_ids` and `feature_ids`: realized baseline IDs
  and reference features, realized deviation IDs and those reference features,
  or recovery dependency scope respectively.
- `definitions$reference` and `$recovery`: saved definitions.
  `definitions$deviation`: saved `method` and named `columns` mapping.
- `provenance$registration$provenance`: the original registration provenance.
  Each interpreted stage has its saved `provenance`, existing `fingerprint`
  (NULL for deviation) and `dependencies`. Deviation also includes `results`,
  with its original output fingerprints. No registration self hash or other
  missing upstream fingerprint is invented.
- `evidence`: the full recovery evidence list keyed by registered episode,
  including support IDs no longer in view rows; NULL before recovery.
- `uninterpreted_stages`: names of present unsupported optional stages.
  Their entries in definitions, provenance and scopes are NULL; evidence is
  also NULL for an uninterpreted recovery stage. Inner fields are not read.

Absent stages have NULL entries. Context is a snapshot at extraction time.
Editing or filtering the returned table does not revalidate it or write it
back to the TSE. Call the accessor again for a fresh view. Conversion with
`as.data.frame()` preserves atomic columns; later tibble conversion is optional.
Neither conversion promises to preserve contextual metadata.

## Failure policy

The extractor reuses validator diagnostics instead of repeating structural
checks or treating every error-severity finding as a reason to discard history.

- Current source changes, unavailable inputs, filtering and unknown fingerprint
  formats permit coherent saved results. Keep all diagnostics and the original
  `changed`/`not_checked` and completeness fields.
- Ambiguous identities, invalid TSE structure or registration, known malformed
  stage records, missing/invalid retained output, and known parent/self/output
  fingerprint inconsistencies prevent extraction. Errors retain the relevant
  component, offending IDs and public call.
- Every present reference is required. Sample views also require present
  deviation records. Episode views with recovery require every parent stage.
- An unknown recovery schema can remain uninterpreted for a sample view; an
  unknown deviation schema can remain uninterpreted for an episode view only
  before recovery. Unsupported extra stages remain opaque. These exceptions
  do not excuse malformed supported records or a downstream stage with no
  required parent, even when that downstream schema is unknown.

Known changes remain visible when other checks are unavailable. An unknown
fingerprint format does not hide independently detectable malformed outputs or
parent inconsistencies. Availability never means biological recovery or that
all current inputs agree with the historical computation.

## Implementation evidence

Tests use the bundled synthetic cases, with expected values stated independently:

- For baseline `(1, 0)`, stored sample deviations are
  `0, 0.75, 0.25, 0.125, 0.125, 0.5, 0.125`. The saved candidate, confirmation
  and rebound occur at relative days 2, 6 and 8, with six window visits.
- Removing the day-4 sample leaves its historical row with missing values and
  retains confirmation at day 6 and the full `s2, s3, s4` evidence run.
- A sample removed before deviation stays `not_computed`; removing every sample
  gives typed empty current tables and an available historical episode.
- Reordering, changed annotations, exclusions, absent stages, missing baseline,
  additions, unknown schemas/formats and corrupted outputs/parents exercise
  the different availability and failure policies.
- Input serialization verifies preservation; a targeted validation counter
  verifies one selected-analysis validation per call and a fresh check on the
  next call. Other malformed named analyses do not contaminate the selection.

The README, function help and vignette execute extraction examples. No new
runtime dependency or plotting implementation is introduced.
