# Reference and deviation validation

`validate_recovery()` extends the version-1 report from
[RFC 001](rfcs/001-registration-validation.md) with the analytical checks in
[RFC 002](rfcs/002-personal-baseline-deviation.md). It accepts the same TSE and
analysis selector and returns the same summary and diagnostic DataFrames. It
never repairs metadata, adds timestamps, recomputes a deviation or refits a
reference. There is no replacement API; changed definitions require a new
named analysis.

## Read the three summary fields together

- `structural_valid`: FALSE for a demonstrated broken container, record or
  authoritative output; NA when an unsupported schema, stage or fingerprint
  format prevents a conclusion and no structural failure is known; TRUE
  otherwise.
- `validation_complete`: whether every required check could run. A comparable
  source or fingerprint difference can be fully checked and still fail. Missing
  historical inputs, uninterpretable sources and unsupported formats leave
  checks incomplete.
- `dependencies`: `changed` if any relevant change is known, otherwise
  `not_checked` when a required comparison is unavailable, and `unchanged`
  only when the required comparisons ran and agreed. Existing registration-only
  meanings, including the case with no retained included sample, are preserved.

For example, removing a baseline and editing a retained deviation produces
both a historical-input finding and an output inconsistency. Dependencies are
`changed`, validation is incomplete, and the demonstrated output inconsistency
makes structure invalid. A missing baseline never hides an independently
checkable output error.

Sample and feature scopes and the registered/retained counts retain their
registration definitions. New identities are not enrolled. A reduced scope is
not automatically a data change: reference-only validation can remain complete
when only an unused feature or non-baseline sample was removed. Removing inputs
needed by an existing analytical stage leaves that stage incompletely checked.

## Additional diagnostic codes

Existing registration codes remain unchanged. Analytical diagnostics identify
the stage or field in `component` and retain complete offending IDs in `ids`.
Message text and row order are not contractual.

| Code | Severity | Meaning |
|:-----|:---------|:--------|
| `REFERENCE_RECORD_INVALID`, `DEVIATION_RECORD_INVALID` | error | A known record has malformed fields or inconsistent identities. |
| `SCHEMA_UNSUPPORTED` | error | A record version is unknown; its inner layout is not interpreted. |
| `STAGE_UNSUPPORTED` | error | A stage such as recovery, or unknown owned content, is outside the implemented checks. |
| `FINGERPRINT_FORMAT_UNSUPPORTED` | error | The format or current encoding compatibility cannot support fingerprint comparisons. This alone is not a detected data change. |
| `FINGERPRINT_CHANGED` | error | A stored record or its parent fingerprint does not agree. |
| `ANALYTICAL_INPUT_CHANGED` | error | A consumed current source differs from its recorded dependency. |
| `ASSAY_MISSING`, `ASSAY_AMBIGUOUS` | error | The recorded assay cannot be selected uniquely. |
| `ASSAY_VALUES_INVALID` | error | A consumed source no longer has accepted numeric values. |
| `ASSAY_READ_FAILED` | error | The required assay block cannot be read or converted; its comparison remains unavailable. |
| `RESULT_INCONSISTENT` | error | A retained owned output is absent, malformed, or inconsistent with its recorded hash. |
| `REFERENCE_INPUT_MISSING` | info | Baseline samples or selected features needed for current reference comparison were removed. |
| `DEVIATION_SAMPLE_MISSING` | info | A sample in the recorded deviation scope is no longer available for comparison. |
| `BASELINE_SUPPORT_LIMITED` | info | Missing baseline, one sample or one sampling time limits interpretation; this is not itself a structural error. |

An invalid or unavailable source does not disable unrelated comparisons.
Stored outputs can still be checked when the assay is unavailable, and another
sample's comparable source change remains reportable when one consumed column
contains invalid values. Unknown stages do not suppress interpretable earlier
stages or other named analyses.

## Detection boundaries

Registration-only analyses do not select or realize assay values. Analytical
checks use the fixed reference feature IDs and relevant retained source sample
IDs; they do not validate unrelated assays, unselected features, excluded
sample abundances or missing-baseline episode abundances. Matrix-like extraction
may materialize the requested block. No bound on backend I/O or memory is
promised.

Source hashes describe the measurements before closure: multiplying baseline
counts is a source change even when its composition stays equal. Output hashes
refer to the stored deviation and status, and parent hashes link historical
records. The validator compares these records; it does not estimate the
reference or recalculate an expected deviation from current measurements.

`deviation_status = "computed"` records that the calculation occurred. It does
not assert that dependencies are still current. The result columns remain
unchanged even when validation detects a problem.

Unknown fingerprint encoding must not produce a false hash-change finding.
Structural and independently known source/output failures remain reportable.
Fingerprints detect ordinary edits, not adversarial rewriting of all snapshots
and hashes. Manual editing of stored analysis records is unsupported.

Limited baseline support is descriptive, not an uncertainty estimate. Validation
makes no statement about biological recovery, calibration or clinical validity.
Recovery outcomes and their supporting observations remain later implementation
work.
