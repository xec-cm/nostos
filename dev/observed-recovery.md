# Observed recovery

`add_recovery(tse, analysis_id, rule)` implements the accepted
[RFC 003](rfcs/003-observed-recovery.md) observational rule. It adds an episode
record to an existing named analysis after reference and deviation calculation.
There are no defaults, fitted thresholds or estimates of continuous recovery.

## Specify the rule before calculating

Supply a plain list with exactly four finite ordinary numeric scalars:

| Field | Meaning | Range |
|:------|:--------|:------|
| `threshold` | Maximum deviation for a within-band visit | 0 to 1, inclusive |
| `persistence` | Minimum observed span of a confirming run | Positive |
| `max_gap` | Maximum gap between consecutive visits in that run | Positive |
| `horizon` | Last relative time eligible for a result | Positive |

Durations use the registered unit. Persistence greater than the horizon is
allowed, but cannot produce confirmation. Comparisons are exact; no rounding,
tolerance, interpolation or calendar conversion is applied.

Current samples must equal the realized deviation scope as a set. Reordering
is allowed, as is removing original features unused by the reference. Required
baseline samples, features, source measurements, registration metadata and
stored deviations must still be available and unchanged. Empty references and
an empty realized deviation scope remain valid explicit missing-baseline cases.
A repeat call errors, including an identical rule. All work finishes before the
selected analysis is updated; use another analysis name for another definition.

## Read the outcome

Relative time is measured from the episode's selected origin boundary. Detection
starts at the origin event's start, potentially before time zero for an end
origin. Return and confirmation start at zero; both windows include the horizon.
Samples at exactly equal times form one visit. All deviations in a visit must
be within the threshold; one outside value makes the visit outside.

After the first detected outside visit, the first later within-band visit is
the first return. A confirming run requires at least two distinct times spanning
persistence, consecutive gaps at most max_gap and no intervening outside visit.
The gap from perturbation to a candidate does not limit eligibility. A failed
candidate can be followed by a later confirming run. The first confirmed run is
retained, and the first subsequent outside visit through the horizon records a
rebound without removing confirmation.

| Status | Interpretation |
|:-------|:---------------|
| `not_evaluable` | Missing baseline, unresolved overlapping events, or no visits in the return window, in that precedence |
| `no_detected_perturbation` | No outside visit in the detection window |
| `no_observed_return` | Perturbation detected, without an eligible later within-band visit |
| `unconfirmed_return` | A return was observed without a confirming run |
| `confirmed_return` | Later observations confirm a run under the stated rule |

Any other registered event for the same subject overlapping the closed interval
from the origin event's start to origin + horizon prevents evaluation. This
includes other episodes, endpoint touches and events after potential
confirmation; other subjects do not block evaluation. There is no implicit
attribution of effects to one of the overlapping events.

Coverage is independent: `none`, `ends_before_horizon` or `reaches_horizon`.
Visits beyond the horizon contribute coverage and last observed time only.
Confirmation describes observed support, not continuous or permanent recovery,
health, functional restoration or a causal effect.

## Inspect the stored record

The selected `metadata(tse)$recoverome$analyses[[analysis_id]]$recovery` contains:

- `schema_version = 1L` and the normalized `observed_run_v1` definition.
- `episodes`, a `S4Vectors::DataFrame` in registered episode order: status,
  reason, coverage, perturbation/first-return/candidate/confirmation/rebound
  times, last observed time and distinct return-window visit count.
- `evidence`, named by episode: evaluated and coverage sample IDs, each selected
  visit, the confirming run and blocking event IDs. Sample IDs are ordered by
  time, then registered sample order for ties. Empty selections are `character()`.
- `dependencies`, containing complete registration/reference/deviation hashes,
  the realized deviation sample IDs and reference feature IDs.
- `provenance`, including package version, UTC creation time and canonical
  fingerprint format, plus a `fingerprint` over the recovery record itself.

Outcome times are doubles relative to the origin; unavailable times are
`NA_real_`, reasons outside `not_evaluable` are `NA_character_`, and visit counts
are integers. An unconfirmed candidate equals the first return; a confirmed
candidate begins the winning run. Not-evaluable episodes retain coverage and
selection evidence, with outcome times missing.

The deviation parent hash covers its existing versioned record, including
method, column mapping, realized scope, source/result hashes and provenance;
it adds no field to that upstream record. Recovery hashes use the existing
`recoverome_inputs_v1` canonical encoding and omit the self fingerprint from
its own projection. No recovery columns are added to `colData()`, and unrelated
analyses, assays, trees, links and metadata are preserved.

## Validate historical results after filtering

Calculate outcomes before removing their input observations. Subsequent TSE
filtering preserves the episode table and evidence exactly. Removing a recorded
sample yields `RECOVERY_INPUT_MISSING`; required comparisons become incomplete.
A simultaneously detectable source or stored-result change still takes priority
in the dependency summary. Validation checks readable parent and self hashes
independently, including when another stage is unavailable or unsupported.

The version-1 report keeps its existing schema. `RECOVERY_RECORD_INVALID`
diagnoses malformed known records or inconsistent result/evidence identities.
The validator checks stored invariants and dependencies without running the
classifier, refitting, repairing records or deleting historical evidence.
Fingerprint checks detect ordinary edits; manual rewriting of records is
unsupported. See [analytical validation](analytical-validation.md) for the
summary fields and detection boundaries.

The executable README, vignette and `add_recovery()` example use the bundled
`observed_recovery` data: an explicit rule detects perturbation at day 0, a
candidate at day 2, confirmation at day 6 and rebound at day 8. Those numbers
illustrate the rule and do not calibrate or validate a biological threshold.


The [follow-up and filtering evidence map](recovery-history.md) contrasts a
fresh analysis with a filtered historical record, including independent named
analyses, removal of supporting visits and coverage beyond the horizon.
