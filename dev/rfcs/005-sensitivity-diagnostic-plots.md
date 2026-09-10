# RFC 005: rule sensitivity and diagnostic plots

Status: accepted through maintainer merge of PR #49 on 2026-09-10
(commit `d0f8314`). Implementation belongs to #44 and #45.
This extends the existing descriptive method, not its estimator or inference.
Evidence: [prespecified qualification](../qualification/README.md).

## Rule sensitivity (#44)

`recovery_sensitivity(tse, analysis_id, rules)` evaluates explicitly supplied rules
against one saved deviation stage. It returns an ordinary `S4Vectors::DataFrame`
with one row per **scenario x originally registered episode**, in supplied scenario
order and registered episode order. It does not write to or modify the input TSE,
its original recovery, provenance, other analyses or fingerprints. A saved recovery
stage is optional and, if present, remains the original result.

`rules` is a data.frame or DataFrame with exactly five columns: `scenario_id`
(unique nonempty unpadded character IDs), `threshold`, `persistence`, `max_gap`,
`horizon` (ordinary numeric scalars per row with the existing rule bounds).
At least one row is required. Reject malformed rules and duplicate IDs before
calculation, with recoverome condition classes and offending scenario IDs. Different
IDs with identical rules are retained. No Cartesian grid is inferred, optimized or
ranked; the caller supplies every scenario. Baseline/sampling sensitivity requires
new analyses and remains outside this function.

Result columns: `scenario_id`, `analysis_id`, `episode_id`, `subject_id`, the four
rule values, `evaluation_state`, `evaluation_reason`, the existing episode result
fields from `recovery_results()` (reference support, baseline counts/diameter,
status/reason/coverage, all outcome times and visit count), plus `structural_valid`,
`validation_complete`, `dependencies`, `current_present`. Use existing atomic types
and typed missing columns; no list columns or implicit conversion to tibble.

Eligibility and failure policy:

- Require a supported, coherent registration, reference and deviation stage.
  Structurally invalid/ambiguous inputs, corrupt required outputs or unsupported
  required schemas error before producing misleading results. Reuse current
  validation/extraction policies; do not duplicate container checks.
- With complete unchanged consumed inputs, evaluate each rule and retain every
  registered episode. `evaluation_state = "evaluated"`; `evaluation_reason = NA`.
  Legitimate `not_evaluable` outcomes (missing baseline, overlapping events,
  absent window visits) remain evaluated results with their existing reason.
- If relevant source inputs changed, use `evaluation_state = "not_evaluable"`,
  `evaluation_reason = "inputs_changed"` for all scenario/episode rows. Missing
  required historical inputs give `"historical_inputs_unavailable"`; unsupported
  comparison formats give `"validation_incomplete"`. Changed takes precedence.
  Do not recompute from a mixture of old deviations and new inputs. Context and
  known baseline support remain; scenario outcome fields are typed missing.
- Conservatively require the complete realized deviation input scope (as current
  add_recovery does), including required baseline samples/features. Pure reorder
  is permitted; removal of unused features alone does not prevent calculation.
  Do not pretend hashes reconstruct a removed sample's distance. Scope additions
  are not enrolled and must follow the existing scope-warning policy.

`metadata(result)$recoverome_sensitivity` contains `schema_version = 1L`, the full
input rules, the fresh validation report, the existing extracted analysis context,
complete per-scenario episode evidence, and provenance (package version, creation
time, parent definitions/scope/fingerprints and rule-method version). Unavailable
scenario evidence is NULL with the explicit reason; never borrow original recovery
evidence as if it supported a new rule. This is a snapshot, not a mutable live view.

`plot_sensitivity(x)` accepts this result/context and returns an editable ggplot:
scenario rows x subject/episode columns, color/shape distinguishes observed status
and unevaluable scenarios, with parameter values identifiable in labels. Preserve
scenario order; no preferred scenario, averaging of categorical outcomes or
inferential uncertainty. Reject missing/inconsistent required context after
arbitrary table mutation; regenerate a result instead of guessing provenance.

Validation: numerical/status/evidence equivalence to independent full analyses
for every valid rule; untouched serialized TSE; missing/changed historical inputs;
legitimate non-evaluable episodes; repeated episodes; exact thresholds/gaps; all
requested scenarios visible and visual review of dense/unevaluable examples.

## Diagnostic plots (#45)

Each function takes `(tse, analysis_id, scope = "current")`, with exact `current`
or `historical` semantics from extraction, and returns an ordinary editable
ggplot. Validate/extract once through shared preparation when useful. Show subject
AND episode for repeated exposures. No mutation, refitting, interpolation, causal
attribution or inferential confidence bands. Empty selections return an informative
empty plot with preserved context. This is a new diagnostic-plot behavior: the
existing `plot_recovery()` rejects a selection with no eligible episodes.

### plot_reference()

Show baseline observations against registered time relative to origin, with a
separate support summary: recorded sample count, distinct time count, support state
and baseline diameter. Baseline points use stored deviations when the realized
sample result is retained/readable; before deviation, derive distance to the saved
profile only when the baseline values needed for that point are available and
verified unchanged. Label derived values as current verified baseline distances.
Never refit the profile. If source comparison fails or input was removed, display
an identity/time availability marker without fabricating a distance. Historical
counts and diameter remain labelled as recorded, not recalculated for the view.
A single sample has no estimable pairwise variation; tied samples are shown as
samples at one time, not independent temporal replication. State the fixed assay,
feature scope and mean-composition reference in plot context.

### plot_sampling()

Show registered sample times as visits, original event intervals/point events,
chosen origin and, when stored, the recovery horizon. Identify consecutive gaps
and distinguish those exceeding the stored max_gap; without a recovery rule, show
actual gaps without inventing a cutoff or horizon. Mark removed historical samples
and retain their recorded times. Do not use edited current metadata as if it were
the registered calendar. Display multiple samples at one time without moving the
underlying time coordinate. This plot uses registration context and can precede
reference/deviation calculation.

### plot_recovery_overview()

One row per subject/episode, with the original observed perturbation/first return,
winning candidate/confirmation/rebound and recorded follow-up on a common relative
time axis in the registered unit. Show categorical status and coverage separately.
First return and winning candidate can differ; confirmation and rebound can coexist.
Include unavailable/not-computed/not-evaluable episodes explicitly. Mark whether
evidence is currently available, historical or incomplete; do not erase saved
milestones after filtering. Events and horizon provide context without implying
continuous recovery between milestones. A common axis does not estimate comparable
biological recovery across different reference definitions.

## Shared preservation and documentation

Reuse existing evidence/context definitions, not new result copies hidden in
colData. Figure captions identify the historical scope, validation state, time
unit and sampling limitations. Missing and unsupported information remains visible.
New user help, offline examples and representative visual inspection accompany
implementation. The existing plot_recovery API retains its single purpose.
Any incompatibility found during implementation must be proposed explicitly with
migration guidance; this document does not authorize silently changing current
result schemas or the accepted method.
