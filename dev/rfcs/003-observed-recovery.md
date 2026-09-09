# RFC 003: Observed recovery

Issue: [#13](https://github.com/xec-cm/recoverome/issues/13).
Status: **proposed for maintainer review**. Merging accepts the operational
rule and storage contract below for later implementation; this PR adds no
analytical API, statistical model or benchmark.

## Decision and interpretation

The question is: after observing a deviation outside a declared band, which
observed return is supported by further visits spanning a declared duration,
without an intervening outside observation or an excessive observation gap?

Use RFC 002's fixed personal reference and Bray--Curtis deviation. Require the
caller to specify the band, duration, maximum gap and horizon. A confirmed
return describes this observed sequence. It does not establish uninterrupted
recovery between visits, permanent recovery, functional restoration, health,
a causal effect, or a latent time-to-recovery distribution.

Separating a first return from persistence has precedents. For example,
[Song et al. (2021)][song] distinguish hitting and settling times in a microbial
reactor model. Their model and percentage bands do not validate this RFC's
observational rule or supply defaults for Bray--Curtis deviation.

[RFC 001](001-registration-validation.md) governs registration and time;
[RFC 002](002-personal-baseline-deviation.md) governs references, deviations,
limited baseline support and fingerprints. Their decisions are unchanged.

## Interface and preconditions

```r
add_recovery(tse, analysis_id, rule)
```

`analysis_id` selects an existing supported registration, reference and
deviation. `rule` is a plain, uniquely named list with exactly these four
required fields, supplied without partial matching or defaults:

| Field | Meaning and accepted value |
|:------|:---------------------------|
| `threshold` | Finite numeric scalar delta in [0, 1], in RFC 002 deviation units. Within means deviation <= delta. |
| `persistence` | Finite numeric scalar P > 0, the minimum observed span from candidate to confirmation. |
| `max_gap` | Finite numeric scalar G > 0, the largest allowed gap between consecutive visits supporting persistence. |
| `horizon` | Finite numeric scalar H > 0, the last eligible relative time. |

Numeric means an ordinary integer/double scalar, normalized to double;
logical, missing, classed and non-finite values are invalid. P, G and H use
the registered time unit. P may exceed H: confirmation will then be impossible,
which is an explicit design rather than an inferred alternative rule.
Comparisons use the stored numeric values, without rounding or a hidden
tolerance. Delta = 1 necessarily detects no perturbation from valid deviations.

These values must be chosen and justified before inspecting the desired
outcome. They are operational parameters, not estimated biological limits.
In particular, do not derive delta automatically from `baseline_diameter`,
a baseline quantile, sample count, a p-value or absence of significance.
Single-sample and single-time references remain usable descriptively; report
their RFC 002 support without upgrading it to evidence of stability.

Before calculating, verify the full reference/deviation dependency chain
under RFC 002. Every sample in the realized deviation scope, every selected
baseline and every selected feature must still be present; sample reordering
is allowed, additions or removals are not. Original unselected features may
be removed. Parent records, consumed source values and owned deviation/status
columns must agree with their fingerprints. Unavailable or changed dependencies
are errors for this new calculation. This intentionally requires calculating
outcomes before filtering results; a new subset analysis requires a new name
and explicit rerunning of its stages.

Return a TSE. A repeated recovery addition errors even for the same rule.
Check all inputs before writing; errors leave the entire input unchanged.
Do not add a replacement operation, exported rule constructor or method registry.

## Observation window and visits

For episode e, let O be its selected origin-event boundary, and S the start
of that same event. Use the registered numeric coordinates:

```text
t = sample_time - O
A = S - O                     # zero for a start origin; <= 0 for an end origin
detection window = [A, H]
return/confirmation window = [0, H]
```

All relevant relative-time arithmetic must remain finite. A sample during an
event can demonstrate deviation before an end origin, while a candidate cannot
precede the selected boundary. Baseline eligibility remains strictly before S
as specified in RFC 002. A start origin permits confirmation during the event;
a caller who requires post-exposure recovery must select an end origin when
registering the analysis. No automatic boundary switch is made.

Use included samples from their own registered episode only. Sort a temporary
view by exact registered time; use registered sample order to break ties.
Do not sort the TSE, borrow another episode's samples or infer membership.
All samples at one identical numeric time form one visit. It is within-band
only when **every** sample in the visit has a valid computed deviation <= delta;
it is outside when at least one valid computed deviation is > delta. This
conservative rule does not average discordant samples or count simultaneous
samples as repeated visits. It does not assert that they are technical replicates.

An included episode without a reference has `missing_baseline` deviations
throughout and is not evaluable. In an episode with a reference, a missing,
non-finite or non-computed deviation is a malformed/inconsistent parent result
and errors before calculation; never drop that sample from a visit. Excluded
samples remain excluded and do not enter any visit. A mixture of computed and
missing-baseline statuses within a referenced episode is likewise an error.

## Candidate, confirmation and rebound

Evaluate these operations in chronological order:

1. Find the first outside visit in [A, H]. Its time is
   `first_perturbation_time`; this is detected deviation, not proof of causation.
2. Eligible return visits are within-band visits in [0, H] strictly after that
   outside visit. Their earliest time is `first_return_time`. Within-band visits
   before detected deviation do not constitute recovery.
3. Form runs of eligible within-band visits. Any outside visit ends a run;
   a gap greater than G also ends it, and the next within-band visit begins a
   new run. Equality to G is permitted. The gap from detected deviation to the
   first candidate is not constrained: it cannot establish when return occurred.
4. In a run starting at c, confirmation is its first visit q satisfying
   q - c >= P. All consecutive gaps from c through q must be <= G and all
   observations there must be within-band. P > 0 therefore requires at least
   two distinct visit times; simultaneous samples cannot confirm one another.
5. Select the first run that reaches confirmation. Store its start as
   `candidate_time` and q as `confirmation_time`. If no run confirms, store
   the first eligible return as `candidate_time`, if one exists. Failed earlier
   attempts remain visible through `first_return_time` and the evaluated IDs.
6. After confirmation, the first outside visit through H is `rebound_time`,
   even if separated by a long gap. It records an observed rebound without
   dating its onset. Preserve the first confirmed result; later rebound or
   subsequent returns do not replace it.

A long gap breaks support; it does not prove an intervening outside state.
Confirmation is established at q, not already known at c. Neither c nor q is
interpolated or represented as an interval-censored first latent recovery.
More frequent visits can change this operational outcome and its ascertainment.
The package does not turn these times into a survival response, infer independent
censoring, or select a threshold that gives a preferred comparison.

## Additional events and repeated episodes

RFC 001 events have no exposure-type classification. For this first rule,
any **other registered event of the same subject** overlapping the closed
interval [S, O + H] makes the episode not evaluable with reason
`unresolved_events`. Determine subject through the event's registered episode;
exclude only the episode's own origin event. Check events in other episodes
of that subject as well as additional events in the same episode. Point events
and touching endpoints overlap. Events of other subjects do not.

This is a deliberately conservative applicability policy, not a claim that
every event is a perturbation. It also applies when the additional event is
after a possible confirmation: do not silently shorten the horizon, reinterpret
it as rebound, or keep only the favorable early segment. Preserve the blocking
event IDs. The cost is excluding some scientifically compatible event records;
a reviewed event-type/selection or explicit interruption policy is a possible
later extension. Choose an appropriate horizon or explicitly registered study
design before interpreting the rule. Undocumented exposures cannot be detected.

Episodes are evaluated separately with the same supplied rule. Distinct IDs,
non-overlap or separate outputs do not establish statistical independence.
No cross-episode reference borrowing or pooling is introduced.

## Outcomes and follow-up coverage

Evaluate the primary outcome in this order:

| `status` | Condition; `reason` where applicable |
|:---------|:------------------------------------|
| `not_evaluable` | Missing reference: `missing_baseline`. Otherwise an overlapping additional event: `unresolved_events`. Otherwise no visits in [0, H]: `no_observations_in_window`. |
| `no_detected_perturbation` | At least one visit in [0, H], but no outside visit anywhere in [A, H]. |
| `no_observed_return` | Deviation was detected, but no eligible within-band return was observed. |
| `unconfirmed_return` | At least one eligible return occurred, but no run met persistence and gap requirements. |
| `confirmed_return` | A qualifying run exists; a later rebound does not change this status. |

`reason` is NA for statuses other than `not_evaluable`. Not-evaluable episodes
have NA event/return/confirmation/rebound times; still record their blocking
event IDs and available follow-up. A run interrupted by an outside observation
before confirmation remains an unconfirmed return unless a later run confirms.
A rebound is represented by `rebound_time` rather than erasing prior confirmation.
No detected perturbation is not evidence that no perturbation occurred.

Coverage is a separate field derived from **all included episode sample times
at or after O**, including observations beyond H:

- `none`: no such observation; `last_observed_time = NA_real_`.
- `ends_before_horizon`: the latest such observation is before H.
- `reaches_horizon`: at least one such observation is at or beyond H.

Record that latest time as `last_observed_time`. Reaching H does not require
a visit exactly at H, establish adequate density, or certify the intervening
state. A visit beyond H contributes its time to coverage but its deviation
cannot detect perturbation, confirm a candidate or count as a rebound for
this rule. All realized deviations are still read/verified as parent-dependency
checks, as required above. An empty [0, H] with a later sample can therefore
be `not_evaluable` with coverage `reaches_horizon`.

For example, `no_observed_return` with `ends_before_horizon` states what was
observed before follow-up ended; it does not assert non-recovery through H.
A confirmed return can also have follow-up ending before H. No outcome here
is assigned a right-censoring indicator or a censoring time.

## Authoritative storage and dependencies

Add only `recovery` under the selected analysis, preserving the namespace and
analysis schema versions. Create no sample-level recovery columns: this result
belongs to episodes, and existing `owned_columns` remains unchanged.

The recovery subrecord is a plain list with these fields:

| Field | Content |
|:------|:--------|
| `schema_version` | `1L`. |
| `definition` | `method = "observed_run_v1"`, the four normalized rule fields in interface order, and the registered `time_unit`. |
| `episodes` | DataFrame in registered episode order, with the columns defined below. Every registered episode receives one row. |
| `evidence` | Named list by episode ID, containing the ID vectors defined below; empty vectors are `character()`. |
| `dependencies` | Canonical registration, reference and entire deviation-record fingerprints, plus the realized deviation sample IDs and selected feature IDs. Use RFC 002's projections and fingerprint recipe; do not add a new fingerprint field to upstream records. |
| `provenance` | Package version, UTC `created_at` and RFC 002's `fingerprint_format`. |
| `fingerprint` | Hash of the preceding recovery fields, using RFC 002's canonical plain-R projection conventions and their listed order, excluding this field. |

Episode columns are `episode_id`, `status`, `reason`, `coverage` (character);
`first_perturbation_time`, `first_return_time`, `candidate_time`,
`confirmation_time`, `rebound_time`, `last_observed_time` (double);
and `n_window_visits` (integer, distinct observed times in [0, H]).
All times are relative to the registered origin and missing times are
`NA_real_`. For a missing baseline, visit counts and coverage describe available
times without asserting that their deviations were evaluable.

For each episode, `evidence` contains `evaluated`, `coverage`, `perturbation`,
`first_return`, `candidate`, `confirmation`, `confirmation_run`, `rebound`,
and `blocking_events`. The first two contain all included sample IDs in
[A, H] and [0, infinity), respectively. The next six identify all samples at
the corresponding selected visits, except `confirmation_run`, which identifies
all visits from the selected candidate through confirmation. Absent findings
have empty vectors; without confirmation, `confirmation_run` is empty.
Not-evaluable episodes retain the selection vectors and blocking event IDs
but no selected outcome evidence. Sample vectors use chronological order with
registered order for ties; blocking events use registered event order.

The evidence records selection and support, never another copy of sample
compositions or deviations. Finding the first qualifying run and absence of
outside observations depends on the entire evaluated sequence, not only the
successful confirmation visit. Coverage also depends on times beyond H;
these IDs and registered times are covered by the parent snapshots/fingerprints.
All dependency comparisons remain identity-based and assay reordering is harmless.

After filtering, preserve the episode record and evidence exactly. Losing a
supporting sample makes its current source/result comparison unavailable; it
does not erase historical confirmation or turn the episode into a new outcome.
Changed parents or outputs are dependency errors; unavailable comparisons are
`not_checked` and incomplete unless another change is known, following RFC 002.
The stage-aware validator must verify the recovery fingerprint, its parents,
IDs and result invariants without recomputing outcomes or repairing data.
Registration scope/count fields retain RFC 001 meanings. The currently
implemented registration-only validator remains unable to certify this stage;
implementation of recovery must extend stage validation before claiming otherwise.

## Worked trajectories and implementation evidence

Use delta = 0.25, P = 4, G = 3 and H = 10 days below. These are illustrative
choices, not recommended defaults. The [arithmetic script](../examples/003-observed-recovery.R)
checks these observations without calling a proposed analytical API.

| Relative times; deviations | Expected evidence |
|:---------------------------|:------------------|
| 0,2,4,6,12; 0.75,0.25,0.125,0.125,0.875 | Confirmed: first return/candidate 2, confirmation 6; coverage reaches H. The outside value at 12 is not a rebound within H. |
| 0,2,4; 0.75,0.25,0.125 | Unconfirmed; span 2 < P and follow-up ends before H. |
| 0,2,3,5,7,9; 0.75,0.125,0.5,0.125,0.125,0.125 | First return 2 fails; candidate 5 confirms at 9. |
| 0,2,4,6,8,10; 0.75,0.125,0.125,0.125,0.5,0.125 | Confirmation 6 persists as a historical outcome; rebound observed at 8. |
| 0,2,7,9; 0.75,0.125,0.125,0.125 | Unconfirmed: gap 5 breaks the first run; the later run spans only 2. |
| 0,4,8; 0.75,0.5,0.375 | No observed return; follow-up ends at 8, with no conclusion through H. |
| 2,6,12; 0.25,0.125,0.75 | No detected perturbation within the window; follow-up reaches H. |
| 12; 0.75 | No observations in [0,H], despite coverage reaching H. |
| 0,2,2,4,6,8; 0.75,0.125,0.375,0.125,0.125,0.125 | Discordant time-2 samples form an outside visit; candidate 4 confirms at 8. |

With event start 10, end 14 and an end origin, observations at absolute times
12,14,16,18 with deviations 0.75,0.25,0.125,0.125 detect perturbation at -2;
a candidate at 0 confirms at 4. A different same-subject event beginning at
22 overlaps [10,24] and makes this episode not evaluable, even if a return
could have been confirmed earlier. The same event for another subject does not.

Implementation acceptance must cover the trajectories above; equality at delta,
G, P and H; simultaneous observations; no reference; missing/corrupt consumed
results; start/end origins; additional and repeated events; parent changes;
filtering supporting observations; reordering; and atomic failure/repeated calls.
Use independent expected times and IDs. No statistical calibration, latent-state
validation, benchmark or sample-size guarantee is supplied by these examples.

Merging approves the explicit parameters, visit grouping, candidate/confirmation
rule, conservative event policy, separate coverage, storage and dependency
behavior. Alternative margins, smoothing, transient-state inference, adaptive
sampling corrections, causal contrasts and survival analyses require separately
reviewed contracts; implementation must not silently choose among them.

[song]: https://www.frontiersin.org/journals/water/articles/10.3389/frwa.2021.590378/full
