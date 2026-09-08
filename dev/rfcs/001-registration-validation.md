# RFC 001: Named analysis registration and structural validation

Issue: [#5](https://github.com/xec-cm/recoverome/issues/5).
Decision: proposed for maintainer review. Merging this RFC accepts the contract
for subsequent implementation; it does not implement the functions below.
This document governs registration only. Reference, deviation and recovery
semantics remain separate RFCs.

## Decision and public interface

Keep TSE as the container, record an immutable-by-contract registration snapshot
in a named analysis, and validate that history against the current object.
Do not intercept TSE subsetting or silently change a registered analysis.

The proposed signatures are:

```r
setup_recovery(
  tse, analysis_id, episodes, events,
  subject_col = "subject_id", episode_col = "episode_id", time_col = "time",
  time_unit, time_origin
)
validate_recovery(tse, analysis_id = NULL)
```

These signatures are non-executable proposals. `setup_recovery()` returns the
TSE with one new registration. `validate_recovery()` returns the report below
and never modifies the TSE. Column selectors are literal, distinct, scalar
column names; there is no non-standard or tidy evaluation. No new public class
or exported helper is needed. Registration creates no sample result columns,
reference, deviation or recovery records.

## Input contract

`tse` must inherit from `TreeSummarizedExperiment` and pass formal S4 validity.
Registration requires at least one row and column. Top-level `rownames(tse)`
and `colnames(tse)` are the feature and sample IDs, respectively: character,
unique on their own axis, non-missing, non-empty, and without leading/trailing
whitespace. Never generate IDs or match by row position. A tree is optional;
existing trees, links, assays and unrelated metadata are preserved.

`analysis_id` is a scalar matching `^[a-z][a-z0-9]*$`, such as `antibiotic2`.
Its reserved prefix is `rec_<analysis_id>_`. Excluding underscores prevents
overlap between prefixes such as `rec_a_` and `rec_a_b_`. Subjects, episodes and
events have separate identity domains and may use other non-empty character
IDs with no surrounding whitespace. Factor IDs are normalized by their labels
in the stored copy; numeric IDs require explicit conversion by the caller.

| Input | Required columns / values |
|:------|:--------------------------|
| `colData(tse)` | Selected subject, episode and time columns. Sample IDs come from `colnames(tse)`. |
| `episodes` | `episode_id`, `subject_id`, `origin_event_id`, `origin_boundary`. |
| `events` | `event_id`, `episode_id`, `start_time`, `end_time`. |

Episode and event tables accept `data.frame` (including subclasses) or
`S4Vectors::DataFrame`. Column names must be unique and non-empty. Required
columns are scalar atomic vectors of the types defined here; no list-valued
identities or times. Extra columns are copied as annotations, never interpreted
as selection rules, statistical parameters or dependencies of registration.
Table row names are ignored. Stored tables use `S4Vectors::DataFrame` and retain
input row order. Subject/episode source columns are character or factor; the
time source column is plain integer or double.
Each selected source name must occur exactly once in `colData(tse)`; duplicate
unrelated column names do not affect this contract. Do not use first-match
selection to resolve an ambiguous source column.

- Every included sample has exactly one episode, a valid subject and a finite
  time. Its subject must equal that episode's subject. Episode `NA` explicitly
  excludes a sample from this analysis. Empty strings do not mean exclusion.
  Excluded samples need no valid subject/time values; those cells are not read
  as analysis inputs. At least one sample must be included.
- Episode IDs and event IDs are unique within the analysis, including across
  subjects. A subject may have several episodes; each episode must have at
  least one included sample. No pooling or cross-episode independence is implied.
- Every event refers to a declared episode. Every episode's `origin_event_id`
  refers to an event belonging to that same episode, and `origin_boundary` is
  explicitly `"start"` or `"end"`. Multiple events per episode are allowed.
- Each event has two finite times with `start_time <= end_time`; equality
  denotes a point event. Unknown/open-ended intervals are outside this initial
  schema. Events and samples need not be supplied in chronological order.
- A sample can belong to different episodes in different named analyses, but
  not to two episodes in one analysis. Reusing a sample as a *reference* is a
  separate question for the reference RFC. Overlapping episodes/events are
  recorded without inferring independence, censoring or sample membership.
- Distinct samples at the same time are permitted. Registration does not
  deduplicate them or count them as independent visits for a recovery rule.
  It imposes no minimum baseline or follow-up sampling requirement.

## Time contract

The initial interface accepts **finite numeric coordinates only**. `time_unit`
is one explicit value: `"seconds"`, `"minutes"`, `"hours"` or `"days"`, with no
partial matching or conversion inside registration. `time_origin` is a
non-empty description of the coordinate system, for example
`"days since enrolment within each participant"`. All sample and event values
for a subject must share that coordinate system across their episodes; this
is an assertion by the caller, not a property recoverable from the numbers.

The episode origin is the selected boundary of its declared origin event.
Relative time means `sample_time - origin_time`, in the declared unit. It may
be negative or fractional. Input coordinates remain recorded; relative times
are derived views and are not stored in a second mutable column at registration.
Arithmetic overflow in this subtraction is an input error. No rounding,
tolerance, sorting or implicit conversion of visit indices is applied.

`Date`, `POSIXct`, `difftime`, text timestamps, non-finite values and logical
vectors are rejected as time inputs. Callers can explicitly convert calendar
times to a common numeric scale before registration and document the origin
and conversion. This keeps timezone and unit conversion outside this first
contract; direct calendar-time support would require an explicit extension.

## Storage, independence and repeated calls

Use public accessors. The only mutation made by successful registration is
adding a record under `S4Vectors::metadata(tse)$recoverome`:

```text
recoverome
  schema_version = 1L
  analyses                         # uniquely named list
    <analysis_id>
      schema_version = 1L
      registration
        source_columns             # named character: subject, episode, time
        time_unit, time_origin     # scalar character
        samples                    # DataFrame: sample_id, subject_id,
                                   # episode_id, time; included samples only
      episodes, events             # normalized DataFrames defined above
      scope
        sample_ids                 # ALL original TSE column IDs, in order
        feature_ids                # ALL original TSE row IDs, in order
      owned_columns = character()  # exact colData names; empty at registration
      provenance
        package_version            # recoverome version, character
        registered_at              # UTC timestamp as ISO-8601 character
```

The samples table follows original TSE column order and normalizes ID factors
to character and integer times to double. Its sample IDs are a subset of
`scope$sample_ids`; the remaining IDs were explicitly excluded at registration.
The full original container scope prevents those pre-existing excluded samples
from being misreported as later additions. Episode/event core ID columns become
character, core time columns become double, and annotation columns are retained.
The snapshot is historical evidence, not a second editable current data source.

Before any write, reject a duplicate analysis ID (even for an identical call)
or an existing `colData()` name beginning with its reserved prefix. No overwrite,
replacement or automatic cleanup is supported. Register a new name for a new
analysis. Reserve the prefix even though setup initially writes no columns;
later result functions must register their exact owned column names.

Count root metadata names before accessing the namespace: no `recoverome`
entry means absent; more than one is `NAMESPACE_INVALID`, even if `$` could
select one. Other metadata entries remain untouched. An absent namespace can
be initialized. A present namespace must
be a uniquely named list with `schema_version = 1L` and a uniquely named
`analyses` list whose names obey the ID grammar; reject malformed or unsupported
namespace versions rather than taking ownership of foreign data. Existing
analysis contents are retained exactly, including historical records. Adding
an independent analysis need not make an older analysis current. An existing
analysis with unsupported contents can still occupy its reserved name/prefix.

No `assay_name` is selected and no assay values or hashes are consumed. Feature
IDs record scope only. Assay validity for a distance, transformations, baseline
eligibility, fingerprints and downstream invalidation belong to later stages.
Manual changes to recoverome's stored snapshots are unsupported: validation
can detect structural contradictions, but is not a tamper-proof audit log.

## Validation report

Return a plain list with `report_schema_version = 1L` and these two
`S4Vectors::DataFrame` components, with typed zero-row tables when appropriate:

| Component | Columns |
|:----------|:--------|
| `summary` | `analysis_id` (character), `structural_valid` (logical), `validation_complete` (logical), `dependencies`, `sample_scope`, `feature_scope` (character), `n_registered`, `n_retained` (integer). |
| `diagnostics` | `analysis_id` (character; `NA` for global issues), `code`, `severity`, `component`, `message` (character), `ids` (list-column of character vectors). |

`analysis_id = NULL` requests all analyses; a scalar ID requests just that
analysis. Invalid argument types/ID syntax or a non-TSE argument raise an
argument error. A missing requested analysis is a report finding, not an
exception. A valid TSE with no namespace or an empty analyses list yields an
empty summary and `NO_ANALYSES` for the all-analyses request.

Interpret the summary columns together, never as one all-purpose pass flag:

- `structural_valid`: `FALSE` for a demonstrated broken container or record,
  `TRUE` for a fully interpretable valid structure, `NA` where an unsupported
  schema/stage prevents that conclusion and no structural failure is known.
- `validation_complete`: `FALSE` when required checks could not run (for
  example an unsupported schema/stage, an invalid identity map, or a missing,
  ambiguous or uninterpretable consumed source column). A comparable changed
  value or a historical subset does not itself make checks incomplete.
- `dependencies`: `unchanged`, `changed` or `not_checked`. Compare only retained
  original identities, normalizing allowed factors/integers as on registration.
  Check included samples' subject, episode and time cells, and retained excluded
  samples' episode cells (which must still be `NA`). Changed/missing required
  source columns, ambiguous source names or invalid source types mean `changed`;
  skip affected cell comparisons without choosing a column or coercion. If no originally
  included sample remains, use `not_checked` unless a change is already known.
  `unchanged` never certifies the unavailable cells of removed samples.
- Scope compares current IDs with the **full original container** on each axis:
  `same` (including pure reordering), `subset` (only removals), `expanded` (only
  additions), `mixed` (both), `empty` (current axis length zero), or `not_checked`
  (ambiguous/unsupported identities). New IDs are never enrolled automatically.
- `n_registered` counts the stored included samples; `n_retained` counts their
  IDs still present. These counts distinguish loss of all analysis samples from
  an empty TSE. Use `NA_integer_` when a count cannot be determined safely.

Validate episode/event references against the original snapshot, not retained
observations. An episode does not become corrupt merely because all its samples
were filtered out. The validator may read dimension names and formal S4 validity,
but must not realize an assay or inspect its values. Unrelated metadata and
annotation changes are not registration dependency changes.

| Code | Severity | Meaning / component |
|:-----|:---------|:--------------------|
| `OBJECT_S4_INVALID` | error | Formal TSE validity fails; stop dependent comparisons. |
| `SAMPLE_IDS_INVALID`, `FEATURE_IDS_INVALID` | error | Current axis IDs violate uniqueness/type/content rules. |
| `NAMESPACE_INVALID`, `ANALYSIS_IDS_INVALID` | error | Namespace shape or analysis naming is ambiguous/broken. |
| `ANALYSIS_NOT_FOUND` | error | An explicitly selected ID does not exist. |
| `SCHEMA_UNSUPPORTED`, `STAGE_UNSUPPORTED` | error | Required checks cannot interpret this version or stage; do not report corruption solely from this. |
| `REGISTRATION_RECORD_INVALID` | error | Snapshot, selectors, time declaration, tables or references violate this contract. |
| `RESERVED_COLUMNS_INVALID` | error | A selected analysis has columns under its prefix not declared in `owned_columns`, or declared columns are missing/duplicated. |
| `DEPENDENCY_COLUMN_MISSING`, `DEPENDENCY_COLUMN_AMBIGUOUS`, `DEPENDENCY_VALUE_CHANGED` | warning | Consumed source metadata cannot still represent the registration. |
| `SAMPLE_SCOPE_REDUCED`, `FEATURE_SCOPE_REDUCED` | info | Original IDs were removed; this alone is not stale assay data. |
| `SCOPE_EMPTY`, `REGISTERED_SAMPLES_ABSENT` | info | Current axis is empty, or no originally included sample remains. |
| `SCOPE_EXPANDED` | warning | New IDs exist outside the recorded scope. |
| `NO_ANALYSES` | info | The all-analyses request found no registrations. |

Global unreadable namespace failures produce no summary rows; a readable
missing requested ID produces a row with `structural_valid = FALSE`,
`validation_complete = FALSE`, states `not_checked` and counts `NA`. Global
container failures apply to each selected readable analysis. Schema failures
stop checks needing that schema and must not cascade into invented missing-field
errors. Report all independently checkable findings. In a `mixed` scope, report
both reductions and additions; absence of included samples is separate.

The M1 validator supports registration-only schema 1. A populated `reference`,
`deviation`, `recovery`, a non-empty ownership manifest, or another unrecognized
record field requires `STAGE_UNSUPPORTED` rather than a complete validation pass.
It may still report independently established registration problems. For an
unsupported version, do not interpret that record's inner layout. Other named
analyses continue to be checked. No timestamps, caches, sorting, repair or
mutation of the input object are allowed during validation. Codes, column types
and enumerated values are contractual; prose and diagnostic row order are not.

## Worked registration and acceptance examples

All times below are numeric days since enrolment within participant `p1`.
Features are `f1`, `f2`; samples `s1`--`s6` are supplied in that order.

| sample_id | subject_id | episode_id | time |
|:----------|:-----------|:-----------|-----:|
| s1 | p1 | e1 | 3 |
| s2 | p1 | e1 | 10 |
| s3 | p1 | e1 | 17 |
| s4 | p1 | e2 | 34 |
| s5 | p1 | e2 | 43 |
| s6 | NA | NA | NA |

| episode_id | subject_id | origin_event_id | origin_boundary |
|:-----------|:-----------|:----------------|:----------------|
| e1 | p1 | ab1 | start |
| e2 | p1 | ab2 | end |

| event_id | episode_id | start_time | end_time |
|:---------|:-----------|-----------:|---------:|
| ab1 | e1 | 10 | 14 |
| ab2 | e2 | 40 | 42 |

Registering `analysis_id = "antibiotic"` produces five snapshot rows, retains
all six TSE columns and both features, and creates no `rec_antibiotic_*` columns.
The implied relative times are `-7, 0, 7, -8, 1` for `s1`--`s5`. `s6` stays
excluded. This is a registration example, not evidence of recovery.

| Operation / input | Required outcome |
|:------------------|:-----------------|
| Validate original registration | Structure TRUE; complete TRUE; dependencies unchanged; both scopes same; counts 5/5. |
| Reorder samples, features or input table rows | Match by ID; same associations and relative times; reordering a registered TSE yields scopes same. |
| Register a second unused analysis name | Both records coexist; first record and unrelated TSE content unchanged. |
| Repeat the name, or pre-existing `rec_antibiotic_note` | Setup errors before any change, even if the repeated arguments are identical. |
| Duplicate/blank IDs, unknown episode, wrong subject, foreign origin event | Setup errors with the failing component/IDs; no partial registration. |
| Two source columns named time, or two root recoverome entries | Setup rejects ambiguity; validator reports DEPENDENCY_COLUMN_AMBIGUOUS or NAMESPACE_INVALID and skips unsafe comparisons. |
| Numeric strings, Date, NA time on included sample, start after end | Setup rejects the input; NA values on excluded s6 remain allowed. |
| Keep s1 and s3 | Structure TRUE; dependencies unchanged; sample scope subset; counts 5/2; e2 history retained. |
| Keep only s6 | Structure TRUE; sample scope subset; counts 5/0; dependencies not_checked; REGISTERED_SAMPLES_ABSENT. |
| Keep no columns | History remains; sample scope empty; counts 5/0; no invented broken-episode error. |
| Remove f2 (or all features) | Feature scope subset (or empty); registration dependency comparisons unchanged. |
| Change s1 time from 3 to 4 | Structure TRUE; dependencies changed; DEPENDENCY_VALUE_CHANGED identifies s1. |
| Keep s1,s3 and change s1 time | Report both subset and changed dependencies. |
| Change excluded s6 time/subject only | No dependency change; assign s6 to e1 instead and report changed membership without enrolling it. |
| Duplicate s1 by column subsetting | SAMPLE_IDS_INVALID even if formal S4 validity succeeds; identity comparisons not_checked. |
| Rename s1 to new1 | Scope mixed, with removal/addition findings; do not guess that it is the same sample. |
| Change an abundance or an unrelated column | Registration dependencies unchanged; no claim about future analytical results. |
| Future schema or unimplemented downstream record | Validation incomplete; never a complete valid-analysis pass. |
| Call validator twice | Same report content apart from non-contractual ordering; TSE identical to its pre-call value. |

The implementation issues must turn these expectations into meaningful API
tests. This RFC adds no test doubles or placeholder analytical functions.

## Alternatives and acceptance

- Explicit membership was chosen over inferred windows: it avoids inventing
  which perturbation explains a sample. Supporting simultaneous membership
  would need a different result representation, reviewed separately.
- Numeric time with explicit units/origin was chosen over automatic calendar
  conversion; it keeps the initial contract small at the cost of caller-side
  conversion. An enrolment coordinate is distinct from an episode's event origin.
- An immutable snapshot plus a structured report was chosen over a TSE subclass
  with custom `[` behavior or silent metadata pruning. Historical loss of scope
  and observed metadata changes must remain distinguishable.
- Registration-only storage was chosen over duplicate derived sample columns.
  The prefix is reserved now; authoritative sample results and their ownership
  will be defined by the consuming stages. There is no speculative assay hash.

The maintainer accepts or amends these proposals through this document's PR.
No separate methodological choice is delegated to an implementation agent by
an unresolved alternative here. After merge, #6 implements registration, #7
implements the report, and #8 verifies preservation; later stage RFCs must
extend validation before claiming their records are fully checked.

## Container evidence

The [SummarizedExperiment vignette](https://bioconductor.org/packages/release/bioc/vignettes/SummarizedExperiment/inst/doc/SummarizedExperiment.html)
documents coordinated assay/column subsetting, while experiment-level metadata
is a list. The [TSE introduction](https://bioconductor.org/packages/release/bioc/vignettes/TreeSummarizedExperiment/inst/doc/Introduction_to_treeSummarizedExperiment.html)
describes tree-linked containers and their subsetting. These container facilities
do not implement the recoverome contract.

Direct checks with R 4.6.1, TreeSummarizedExperiment 2.20.0,
SummarizedExperiment 1.42.0 and S4Vectors 0.50.1 confirm that row/column subsets,
empty subsets and reordering retain experiment metadata. Repeated row/column
selection can yield duplicate IDs while still passing `validObject()`. Explicit
identity and historical-scope checks are therefore required in recoverome.
