# RFC 004: Result extraction and plotting

Issue: [#16](https://github.com/xec-cm/recoverome/issues/16).
Status: **proposed for maintainer review**. Merging accepts the view contracts
below for later implementation. This PR adds no public function, dependency,
analytical calculation or benchmark.

## Decision and interfaces

Provide ordinary tables and a customizable static plot from the authoritative
TSE records. Preserve the distinction between a saved observation, an episode
outcome and the ability to check either against the current data.
[RFC 001](001-registration-validation.md),
[RFC 002](002-personal-baseline-deviation.md) and
[RFC 003](003-observed-recovery.md) retain their scientific and storage choices.

```r
recovery_results(tse, analysis_id, level = "episode", scope = "current")
plot_recovery(tse, analysis_id, scope = "current", episodes = NULL)
```

These are proposed signatures, not executable examples. `analysis_id` is a
required, non-missing character scalar naming one existing analysis, using
RFC 001's ID rules. There is no implicit first analysis, `NULL` selection or
all-analysis aggregation. `level` is exactly `"sample"` or `"episode"`;
`scope` is exactly `"current"` or `"historical"`. Selectors are scalar strings
without partial matching. No `...`, new public class, method registry,
replacement operation or subject/group summary is introduced.

`recovery_results()` returns an `S4Vectors::DataFrame` with the fixed columns
below and no identity encoded only in row names. All result-table columns
are atomic. Full evidence and contextual records go in its metadata, which
S4Vectors supports for arbitrary R objects. This avoids the documented
`as.data.frame()` limitation for list-like DataFrame columns. [S4Vectors manual][s4]

A caller can explicitly use `as.data.frame(view)` and optionally
`tibble::as_tibble(as.data.frame(view))`. IDs and safety flags remain columns;
metadata preservation is not promised by these conversions. Tibble is an
optional downstream tool, with no new dependency in this RFC or required
runtime dependency for extraction. [Tibble conversion documentation][tibble]

## Identity, order and scope

Scope selects rows; it never changes what a saved result means.

| Level | `current` | `historical` |
|:------|:----------|:-------------|
| Sample | Original registered scope IDs still present in the TSE, including originally excluded samples. | Every original registered scope ID, including removed and originally excluded samples. |
| Episode | Registered episodes with at least one originally included sample still present. | Every registered episode, including episodes with no retained samples. |

Use original registration order at each level, regardless of current TSE
order. Excluded samples do not establish current episode membership. New
sample IDs are not enrolled or appended to either view; new feature IDs do
not redefine the recorded feature set. If current scope contains additions,
issue one structured warning with the complete added IDs in condition data
and preserve the validator's scope findings in the returned metadata.
Do not silently hide additions or pretend their results were computed.

Read sample subject, episode and absolute time from `registration$samples`,
joined by ID; calculate relative time using the saved event boundary.
Never combine a historical deviation with edited current `colData()` times
or membership. RFC 001 snapshots only included samples: for an originally
excluded sample, `subject_id`, `episode_id`, `time` and `relative_time` are NA,
even if its current annotations contain values. `included` is FALSE there.

A zero-row selection returns the same typed columns and contextual metadata.
It is different from an unknown analysis, which errors. Arbitrary user
annotations are not automatically joined; callers can join them explicitly
by the returned IDs without ambiguous column names or positional matching.

## Table columns and availability

Both levels begin with these columns, in this order:

| Column | Type and meaning |
|:-------|:-----------------|
| `analysis_id`, `view_scope` | Character; the selected analysis and scope. |
| `current_present` | Logical; current sample presence, or any retained included sample for an episode. |
| `result_state` | Character; `available`, `not_computed` or `removed`, as defined below. |
| `structural_valid`, `validation_complete` | Logical; selected-analysis values from the fresh validation report. |
| `dependencies` | Character; that report's `unchanged`, `changed` or `not_checked`. |

The three validation fields describe the selected analysis, repeated for
visibility after ordinary row selection. They are not row-specific
certificates. `available` means a readable saved value exists, not that all
current dependencies agree or that the result establishes biological recovery.

### Sample level

Append `sample_id`, `subject_id`, `episode_id` (character); `time`,
`relative_time` (double, registered units); `included`, `is_reference`
(logical); `deviation` (double); and `deviation_status` (character).
`is_reference` joins the realized reference selection by sample ID; it is NA
when no reference exists, otherwise TRUE/FALSE, including FALSE for exclusions.

Read deviations and their statuses only from RFC 002's mapped owned columns.
Preserve native statuses `computed`, `missing_baseline` and `excluded`.
These meanings are separate from view availability:

| Situation | `result_state` | Deviation fields |
|:----------|:---------------|:-----------------|
| Sample belongs to realized deviation scope and is retained. | `available` | Saved value/status, including a legitimate NA value for missing baseline or exclusion. |
| Sample belongs to realized deviation scope and was removed. | `removed` | Both NA; a fingerprint cannot reconstruct its numeric value or saved status. |
| No deviation stage, or sample was removed before that stage and never computed. | `not_computed` | Both NA, whether or not the sample is currently present. |

A missing baseline therefore remains an available, explicitly missing-baseline
result; it is not silently relabeled as an unfinished workflow. A retained
owned column missing or inconsistent with its saved output fingerprint is
an error, not `removed` or `not_computed`.

### Episode level

Append `episode_id`, `subject_id` (character); `reference_support` (character);
`n_baseline_samples`, `n_baseline_times` (integer); `baseline_diameter` (double);
then all RFC 003 episode columns except the already included `episode_id`,
in their RFC 003 order and types. These include `status`, `reason`, `coverage`,
the six observed times and `n_window_visits`.

Reference columns project RFC 002's `support`, `n_samples`, `n_times` and
`baseline_diameter`. Without a reference stage they are typed NA; with an
empty baseline selection, preserve `missing_baseline` and its zero counts.
The reference-only stage is useful here even before deviation or recovery.

`result_state` is `available` when a recovery record exists and `not_computed`
otherwise. Missing recovery fields are typed NA, never a fabricated
`not_evaluable` outcome or zero visits. A saved `not_evaluable` outcome is
available with its original reason. An episode is never `removed` merely
because no samples remain: its authoritative recovery metadata still exists.
Preserve the first confirmed outcome, rebound time, original coverage and
support IDs after filtering; do not classify the retained observations again.

### Context and provenance

`metadata(view)$recoverome_view` is a plain list containing:

- `schema_version = 1L` and `selection` with analysis ID, level and scope.
- `validation`: the fresh full report for the selected analysis, including
  global diagnostics, registered/current scope and complete offending IDs.
- `registration`: saved source-column bindings, time unit, origin description
  and the original `episodes` and `events` tables. These retain each selected
  origin-event ID/boundary, its absolute coordinates and blocking-event context.
- `scopes`: the original registration sample/feature IDs and each interpreted
  stage's realized sample/feature scope, copied from its defined source.
- `definitions`: each interpreted reference definition, deviation method and
  column mapping, and recovery definition; absent stages are NULL.
- `provenance`: registration and interpreted stage provenance and existing
  fingerprints, identified by stage. Do not invent missing upstream hashes.
- `evidence`: the full recovery evidence list by registered episode, or NULL
  before recovery, preserving IDs even when they are absent from view rows.
- `uninterpreted_stages`: character names of present but unsupported stages
  not needed at this level. Their entries in definitions/provenance/scopes, and
  recovery evidence when applicable, are NULL. Do not read their inner fields;
  the validation report explains why they were not interpreted.

This metadata is an extraction-time snapshot, including when a user later
filters or edits the returned table. It is not a second persistent result
store or a dynamically updating validator. Ordinary table operations and
conversion may preserve stale context or discard it. To refresh against a
TSE, call the accessor again; never write edited views back implicitly.

## Validation and failure policy

Extraction depends on the stage-aware validation required by #12 and RFC 003.
The currently implemented registration-only validator cannot certify these
analytical stages. Implement this view contract only with the necessary stage
checks in place. Validate the selected analysis once per public call and reuse
that context for projections and plot layers. Checking analytical dependencies
can read and realize the relevant assay blocks under RFC 002; extraction does
not promise an assay-free operation. It never rebuilds a reference, recalculates
a deviation or reruns the recovery rule.

Use the following distinction rather than aborting on every error diagnostic:

| Finding | View behavior |
|:--------|:--------------|
| Missing optional stage in a valid ordered workflow prefix. | Return typed NA and `not_computed` as above. |
| Current source annotations/assay values changed, or required current inputs became unavailable. | Return coherent saved results with the validator's `changed`/`not_checked` and completeness fields. Preserve its diagnostic severities. |
| Removed input or computed sample. | Return historical availability as above; unavailable comparisons cannot become `unchanged`. |
| Ambiguous identities, unreadable registration, malformed required result, missing retained owned output, or inconsistent saved output fingerprint. | Error with the relevant component and IDs; do not return guessed or altered results. |
| Saved parent records disagree with a downstream parent fingerprint. | Error: the available metadata no longer provides one coherent historical chain. Do not join a new reference or registration to an old outcome. |
| Unknown required record schema. | Error rather than guessing its fields. |
| Known record layout but unknown/incompatible fingerprint format. | Readable saved results may be returned with incomplete checks and `not_checked`, unless another actual change is known. |

A sample view requires a readable registration and every present reference
and deviation record. An unsupported recovery record need not block those
earlier values, but remains visible as incomplete validation. An episode view
requires every present reference and recovery record, including the parents
of a recovery result; an unsupported deviation without a recovery does not
prevent extracting an otherwise readable reference. Plotting requires every
present stage it displays. A downstream record lacking a required parent is
malformed, not a missing optional stage. Formal TSE invalidity and an unknown
analysis error before extraction. Do not offer a switch that suppresses these
checks or relabels changed dependencies as valid historical evidence.

## Plot contract

Return one unprinted `ggplot` object, with ordinary customization through
`+ labs(...)` or `+ theme(...)`; do not draw as a side effect or add a custom
plot class. This is a concrete future implementation choice: add a justified
`ggplot2` dependency when plotting is implemented, not in this RFC.
Its layered object interface supports this customization. [ggplot2 reference][ggplot]

Require a deviation stage; otherwise explain that no deviations exist to
plot and that episode extraction can show reference support. With no recovery
stage, show deviations neutrally without an invented threshold, horizon,
candidate or coverage classification.

`episodes = NULL` selects all episodes permitted by scope. An explicit value
is a non-empty unique character vector of those episode IDs, displayed in its
supplied order; unknown IDs or IDs outside that scope error. There is no
implicit switch to historical scope. A plot with no selected episodes errors;
a historical episode with no surviving values can still show saved evidence.

Use one facet per episode, labeled with subject and episode IDs. Use registered
relative times on x and a shared deviation scale [0, 1] on y. Share x limits
across facets, covering their recorded included times, zero and any declared
horizon. A removed sample can determine the historical axis extent but cannot
supply a deviation. Do not substitute current edited times. Display numerical
time units and reference support/sample count in each facet.

The visual rules are:

- Plot each retained computed deviation as an observed point; distinguish
  selected baselines by shape. Do not average simultaneous observations,
  jitter their times, connect points, smooth, interpolate or draw uncertainty
  ribbons. Missing-baseline NA values are not plotted at zero.
- With recovery, show the declared threshold and detection-window band [A,H],
  origin at zero and horizon H. Label the band as declared, never as a reference
  confidence interval. `baseline_diameter` does not define a band.
- Use a separate time-evidence rail for first return, candidate, confirmation
  and rebound. Coincident first return/candidate labels may be combined.
  A candidate-to-confirmation bracket means observed supporting span, not
  an uninterrupted trajectory or latent recovery interval.
- Use each milestone's evidence IDs for first return, candidate and rebound.
  Confirmation and its bracket require the entire `confirmation_run`, including
  intermediate visits. Make the corresponding mark hollow/dashed if any of those
  IDs were removed; otherwise solid. Keep its saved time even if its y value is unavailable.
  Mark removed observation times on the rail, never with invented deviations.
  Explain hollow marks as incomplete current evidence, not uncertain timing.
- Mark observed gaps greater than G using the original evaluated visit times.
  They are observation gaps, not proven outside states. Filtering an intermediate
  sample must not manufacture a new original gap or re-evaluate a run.
- With saved coverage `ends_before_horizon`, distinguish the region from saved
  `last_observed_time` to H as beyond recorded follow-up. With `none`, label
  missing follow-up. Do not recompute coverage from the filtered TSE or require
  a visit exactly at H. Points beyond H are labeled outside the rule window;
  their deviations cannot supply recovery or rebound markers.
- Show the saved status, applicable reason and coverage per facet. With no
  remaining values, say so and retain any historical evidence rail. A filtered
  confirmation must not appear as a newly verified result.

Every plot visibly states the selected scope. If dependencies are changed or
not fully checkable, show a prominent caption and corresponding facet label:
for example, `Saved results; sources changed` or `Historical inputs missing;
checks incomplete`. These are analysis-level validation findings, not estimates
of uncertainty. A changed source is never displayed as a new observation or
used to move a saved event. Baseline support labels likewise make no stability
claim. Customizing a returned plot does not revalidate it.

## Examples and implementation evidence

The [view and sketch script](../examples/004-result-views.R) constructs explicit
illustrative tables and a [static visual proposal](../examples/004-result-views.png).
It does not implement either proposed function. Its trajectories use the
independently stated examples in RFC 003, with illustrative delta = 0.25,
P = 4, G = 3 and H = 10 days; these are not defaults.

For times 0,2,4,6,12 and deviations 0.75,0.25,0.125,0.125,0.875, the saved
candidate is 2 and confirmation 6. After removing only the time-4 sample,
a historical sample view has a `removed` row with NA deviation/status; an
episode view retains confirmation 6 and `reaches_horizon` coverage. The observed
time-6 point remains solid, but confirmation and its bracket show partial
support because their intermediate visit is absent. It must not create a new
original gap from 2 to 6. Editing the current time-6 annotation
to 20 instead yields changed sources, with the saved point still at time 6.

For times 0,2,7,9 and deviations 0.75,0.125,0.125,0.125, the saved outcome is
unconfirmed, the original observation gap is 5 and coverage ends at 9 before
H = 10. Neither the gap nor the region after 9 proves non-recovery. A
reference-only workflow gives support/counts and `not_computed` recovery;
an excluded sample has no invented registered subject or time.

Later implementation acceptance must verify these cases; reordered and empty
scopes; originally excluded and newly added IDs; samples never computed versus
computed then removed; missing-baseline and absent-stage distinctions; all
samples removed; unknown schemas/formats; source changes versus inconsistent
outputs/parents; preservation of the TSE; and table coercion preserving atomic
IDs, statuses and safety flags. Test plotted data, labels and evidence selection
against independently specified values, not just rendered snapshots. Check
readability and that projections share a single validation context; do not
build a generalized rendering or result-cache framework.

Merging approves these selectors, table schemas, availability and failure
policies, metadata snapshots, and observed-evidence plotting conventions.
Alternative table classes, automatic inference after filtering, group summaries,
interactive dashboards, estimated reference bands and modeled trajectories
require separate decisions. The views supply no new statistical estimand.

[s4]: https://bioconductor.org/packages/release/bioc/manuals/S4Vectors/man/S4Vectors.pdf
[tibble]: https://tibble.tidyverse.org/reference/as_tibble.html
[ggplot]: https://ggplot2.tidyverse.org/reference/ggplot.html
