# RFC 002: Personal baseline and deviation

Issue: [#9](https://github.com/xec-cm/recoverome/issues/9).
Status: **proposed for maintainer review**. Merging this document accepts the
choices below for later implementation. This PR implements no analytical
functions and makes no performance or inferential claim.

## Decision

The first reference is an episode-specific, sample-weighted arithmetic mean
of explicitly selected personal baseline compositions. The first deviation
is Bray--Curtis dissimilarity between a sample composition and that fixed
profile. One selected baseline sample gives a descriptive reference;
zero samples gives an explicit missing-baseline state. Repeated observations
are documented without treating their number as evidence of stability.

This is a transparent starting method, not a claim that it is optimal for all
microbiomes. [Dethlefsen and Relman (2011)][dethlefsen] observed temporal basal
variation and different responses across people and repeated perturbations.
[David et al. (2014)][david] documented daily variation and changes associated
with travel and infection. These studies motivate personal, temporally
explicit references; they do not establish this RFC's estimator or a minimum
number of samples as universally sufficient.

The accepted registration contract remains [RFC 001](001-registration-validation.md).
In particular, episode membership is explicit, registration history is
preserved, and sample IDs are distinct from subject and episode IDs.

## Proposed interface and selection

```r
add_reference(
  tse,
  analysis_id,
  reference,
  assay,
  features = NULL,
  preprocessing = "unspecified"
)
add_deviation(tse, analysis_id)
```

These signatures are proposals. Both functions return a TSE without changing
assays, trees, links, identities, unrelated annotations or other analyses.
`analysis_id` identifies an existing supported registration. No new exported
selector, reference class, method registry or replacement function is added.

The data flow keeps registration, reference estimation and deviation separate:

| Operation | Reads | Adds to the TSE |
|:----------|:------|:----------------|
| `setup_recovery()` (RFC 001) | Sample membership, times, episodes and events. | The named registration and original scope; no assay-derived result. |
| `add_reference()` | That registration, explicit baseline IDs and selected assay/features. | Episode profiles, support and their dependencies in `reference`. |
| `add_deviation()` | The fixed reference, its dependencies and retained included samples with a profile. | Deviation/status in `colData()` and a `deviation` record describing their provenance. |

### Baseline selection

- `reference` is an explicit character vector of sample IDs, including
  `character()` when no baseline information is supplied. IDs must be unique,
  non-missing, non-empty and unpadded. No formula, time-window inference,
  selection expression or implicit use of every pre-event sample is supported.
- Every selected sample must be currently present and included in the named
  registration. Its registered episode owns that baseline observation.
  Unknown, excluded or removed sample IDs are errors, not silently discarded.
- Every selected sample must precede the **start_time of its episode's
  origin_event_id**, strictly. This cutoff applies even when the episode's
  `origin_boundary` is `end`. Being before the selected end boundary does not
  by itself make a sample pre-perturbation.
- Other events have no universal exposure classification in RFC 001. The
  caller must exclude samples affected by other exposures, disease, batch
  incompatibility or unsuitable collection conditions. Eligibility is a
  declared design choice, not a conclusion inferred from composition.
- Selection is separate for each episode. There is no automatic borrowing
  across subjects or episodes, including earlier episodes of the same person.
  The same sample cannot be assigned to two episode references through this
  interface. A later explicit cross-episode mapping would require a separate
  contract about its scientific interpretation and dependencies.

### Assay and feature selection

`assay` is a literal, non-empty scalar name occurring exactly once in
`assayNames(tse)`. There is no default assay or inference from its name.
`features` is `NULL` for all currently retained features, or a non-empty unique
character vector of current feature IDs. IDs follow RFC 001's rules. Record
the resolved non-empty feature set and its order; match later data by these
IDs, never by position. Zero retained features is an error. One selected
feature is allowed but gives a necessarily constant composition and zero
deviations; document that uninformative case rather than inventing variation.

Input row/column reordering is harmless. Current identities must be a subset
of the registered identities, with no duplicates or newly added IDs; retained
consumed sample metadata must agree with registration. An explicitly selected
feature subset defines a new reference for that subcomposition. It does not
rewrite the original registration scope.

## Assay values and preprocessing

`add_reference()` reads only selected baseline columns. `add_deviation()` reads
only retained included samples whose episode has a reference. Invalid assay
cells in excluded samples, unselected features or samples with no reference
are not consumed and do not create an assay-validity claim.

The selected assay must supply an integer or double matrix through public
matrix-like extraction/coercion. Base, sparse or delayed storage is acceptable
when the requested block can be converted to an ordinary numeric matrix;
implementations must test these paths before claiming support. Request only
the selected features and consumed samples. Conversion may realize that block;
this contract does not promise bounded-memory processing or control backend I/O.

For every consumed sample, all selected cells must be finite and non-negative,
and their sum must be finite and strictly positive. Logical, character,
complex, missing, negative or infinite values are errors. Zeros are valid,
including features absent from all baselines; there is no pseudocount,
zero replacement, pairwise deletion or implicit feature filtering.

Each sample is divided by its sum over the fixed feature set. Raw counts and
non-negative abundance/proportion estimates are accepted under this declared
closure; logged, centered or signed transformed assays are outside the
intended input contract, even when a particular transformed matrix happens
to contain only non-negative numbers. The caller is responsible for the
assay's scientific meaning and compatible feature definitions.

No rarefaction, depth threshold, batch correction, taxonomic aggregation,
prevalence filtering or time smoothing is performed. Such preprocessing must
be explicit upstream. `preprocessing` is a non-empty character scalar recording
the caller's description or a pipeline/version reference. Its default
`"unspecified"` records absent information; it does not assert raw counts or
validate the description. Store it unchanged with the definition.

Closure removes sample totals from the numerical profile; it does not remove
sampling uncertainty or measurement bias, and it cannot recover absolute
microbial load. [Morton et al. (2019)][morton]
demonstrate why the same proportions can arise under different absolute
abundance changes. No phylogenetic tree is required or consumed.

## Numerical definitions and strength of support

For selected features F and a sample j, let

```text
p[f,j] = x[f,j] / sum(g in F, x[g,j])
B[e]   = explicitly selected baseline samples belonging to episode e
r[f,e] = mean(j in B[e], p[f,j])                 when length(B[e]) > 0
d[j]   = sum(f in F, abs(p[f,j] - r[f,e])) /
         sum(f in F, p[f,j] + r[f,e])           for j in episode e
```

The Bray--Curtis formula is documented in the [vegan reference][bray]. For
unit-sum profiles its denominator is two, so here it is half the L1 distance
between compositions and lies in [0, 1]. Zero means equal composition over F;
it does not establish recovery, health or functional restoration. The mean
profile is chosen as an understandable average, not as the optimizer of a
Bray--Curtis objective. It can lie between distinct observed community states.

Use equal weight per selected sample after closure, not weight by read count,
elapsed time or visits. Duplicate sampling times are allowed and counted
separately; the package cannot infer which observations are technical
replicates. Callers should aggregate replicates or select one representative
upstream if equal sample weighting is inappropriate. Record both the number
of samples and distinct registered times, plus the first and last time.
Irregular or dense sampling can therefore change the reference's weighting;
no independent-and-identically-distributed or stationary model is asserted.

Each registered episode has one `support` value:

| support | Meaning and result |
|:--------|:-------------------|
| `missing_baseline` | Zero selected samples; no profile exists. |
| `single_sample` | One selected sample; profile equals that composition. |
| `single_time` | Multiple selected samples, all at one registered time. |
| `multiple_times` | Multiple selected samples spanning distinct registered times. |

Every state except `missing_baseline` permits descriptive deviations. A single
baseline's self-deviation is zero by construction; it estimates no temporal
variation. Neither `single_time` nor `multiple_times` establishes adequate
biological replication, coverage, stationarity or independence.

For at least two baseline samples, also record `baseline_diameter`, the
maximum pairwise Bray--Curtis dissimilarity among their compositions. For
zero or one sample it is `NA_real_`, not an estimated zero variance. This is
a description of the selected observations, sensitive to their number and
coverage. It is not a prediction interval, null distribution, equivalence
margin or cutoff for recovery. No baseline-scaled score, compatibility flag,
p-value, quantile threshold or uncertainty interval is produced here. A later
recovery-rule RFC must justify any operational margin separately.

## Stored results and atomic operations

Keep the existing analysis and namespace schema versions from RFC 001. Add
versioned `reference` and `deviation` subrecords; do not preallocate them at
registration. An unrecognized version or existing target stage is an error
for an add operation. Reference addition also rejects any existing deviation
or recovery stage; deviation addition rejects an existing recovery stage.
Check all consumed inputs before changing the TSE; a failed call leaves the
entire object unchanged.

### Reference record

The reference subrecord is a plain list with these authoritative fields:

| Field | Stored content |
|:------|:---------------|
| `schema_version` | `1L`. |
| `definition` | Named list: `sample_ids` (normalized requested vector), `assay`, resolved `feature_ids`, `preprocessing`, `normalization = "closure_v1"`, `estimator = "sample_mean_v1"`. |
| `baseline_samples` | DataFrame: `sample_id`, `episode_id` (character), in registered sample order. This is realized selection, not a new membership map. |
| `episodes` | DataFrame in registered episode order: `episode_id`, `support` (character), `n_samples`, `n_times` (integer), `first_time`, `last_time`, `baseline_diameter` (double). Absent baselines have NA times and diameter. |
| `profiles` | Double matrix: rows are resolved feature IDs; columns are episodes with available profiles, in registered episode order. Zero columns are allowed. Missing profiles are not zero-filled. |
| `dependencies` | Registration fingerprint and DataFrame of `sample_id`, `input_sha256` for selected baselines. |
| `provenance` | Package version, UTC `created_at` using RFC 001's timestamp convention, and `fingerprint_format = "recoverome_inputs_v1"`. |
| `fingerprint` | SHA-256 of the reference fields above, excluding this field itself. |

The profile matrix is the reference result; the source assay remains the
source of measurements. Do not store a second copy of sample compositions
or baseline-to-profile deviations in metadata.

### Deviation columns and record

`add_deviation()` creates exactly two authoritative sample columns:

- `rec_<analysis>_deviation`: double, computed dissimilarity or `NA_real_`.
- `rec_<analysis>_deviation_status`: character, one of `computed`,
  `missing_baseline`, or `excluded`.

Populate by current sample ID: retained included samples use their registered
episode; included samples without a profile get `missing_baseline` plus NA;
registered excluded samples get `excluded` plus NA. Invalid consumed values
are errors, not another missing-result status. Include baseline samples in
these calculations; identify them through the realized baseline selection.

Append these exact names to `owned_columns`. Reject either pre-existing
column, even if apparently identical. The `deviation` subrecord stores
`schema_version = 1L`, `method = "bray_relative_v1"`, the exact `columns` mapping,
current `sample_ids` as its realized scope, the reference fingerprint, a
DataFrame of computed `sample_id`, `input_sha256`, a DataFrame of all realized
`sample_id`, `result_sha256`, and package version/UTC `created_at`. Fingerprints
are dependency evidence, not duplicate numeric result tables. Extraction must
read the owned columns and join reference information by episode ID.

## Dependency checks and historical scope

Before `add_deviation()`, require every selected baseline and selected feature
to remain available, the selected assay name to remain unambiguous, and all
reference dependencies and its fingerprint to agree. Removed non-baseline
samples and unselected original features are allowed. Do not use a reference
whose provenance cannot be checked for a new calculation; compute deviations
before dropping baseline inputs. No newly added identities are enrolled.

After results exist, ordinary TSE filtering retains their historical metadata
and selects the sample columns normally. Never rebuild profiles, shrink the
feature set, append new results or recompute values automatically. Removing
reference inputs makes their current comparison unavailable, rather than
proving the historical result was wrong. Removing a computed sample preserves
its recorded historical scope; its old numeric value is no longer available
from the subset's authoritative colData and must not be fabricated on extraction.

The later dependency-validation issue must extend RFC 001's report without
changing its registration-only promises:

| Observation | Required analytical interpretation |
|:------------|:-----------------------------------|
| Relevant source or parent fingerprint differs | `dependencies = changed`; error diagnostic identifies stage and IDs. |
| Required source assay missing/ambiguous or values no longer acceptable | `dependencies = changed`; skip unsafe comparisons and set `validation_complete = FALSE`. |
| Required baseline sample/feature removed | Historical scope finding; affected checks unavailable, `validation_complete = FALSE`. Never call it an unchanged full reference. |
| Computed sample removed | Historical scope finding; its source/result comparisons are unavailable. |
| Retained owned output differs from its result fingerprint, is missing or has invalid type/status | Result inconsistency; report an error without repairing it. |
| Current reordering or unrelated assay/annotation change | No analytical dependency change. |
| `single_sample`, `single_time`, or `missing_baseline` support | Explicit informational finding; no fabricated uncertainty and no structural error solely from limited support. |

Registration scope/count fields retain their RFC 001 definitions. Across stages,
report `changed` if any dependency is known to have changed; otherwise `not_checked`
if a required analytical comparison is unavailable, and `unchanged` only if all
required comparisons ran and agreed. Unsupported stages remain incompletely
checked. Stage add functions must validate their own consumed inputs; they
cannot rely on a registration-only validator claiming a future stage is fully
checked. This RFC does not expand the concurrent #7 implementation's scope.

No replacement is supported in this first workflow. Repeated add calls error,
including identical calls. Use a new named analysis to change selection,
preprocessing, feature scope or method, then explicitly rerun dependent stages.
Do not delete an upstream record while retaining downstream results as current.

## Fingerprint format

Only analytical stages introduce assay fingerprints; RFC 001 registration
still neither selects nor hashes assays. `recoverome_inputs_v1` uses the
following fixed recipe on a canonical plain-R projection `value`:

```r
digest::digest(
  value,
  algo = "sha256",
  serialize = TRUE,
  serializeVersion = 2,
  skip = "auto",
  ascii = FALSE
)
```

Version 2 materializes ALTREP values; `skip = "auto"` omits the serialization
header containing the R writer version. These choices follow the
[R serialization specification][serialization] and [digest documentation][digest].
Unmodified version-3 serialization is unsuitable here: equal values can have
different ALTREP representations and environment-dependent headers. Add a
justified `digest` dependency only when a later stage implements this recipe;
this RFC adds no dependency or hashing code to the package.

Source `value` is a named list of `sample_id`, `feature_ids`, and `values`, in
that order. Use recorded feature order, UTF-8 strings, and an attribute-free
plain double vector with positive zero for all zero values. Integer/double
storage and sparse/dense representations with the same values compare equally.
Scaling counts is a source change even if closure gives the same composition.
Output projections contain `sample_id`, `deviation`, `status` in that order;
missing deviations are replaced by canonical `NA_real_` before hashing.

Parent projections contain `registration`, `episodes`, `events`, `scope` in
RFC 001 field order. Rebuild tables as named lists of their required core
columns in contract order, without row names, annotations or S4 attributes;
rebuild `source_columns` as named subject/episode/time bindings. Exclude later
stages and `owned_columns`. The reference projection uses its field order
listed above, excluding `fingerprint`. Rebuild its tables the same way and
represent `profiles` as a named list of `feature_ids`, `episode_ids`, and
column-major double `values`. Recursively rebuild remaining lists/vectors with
contractual names/types/order, UTF-8 strings, and canonical numeric NA/zero;
retain no classes or incidental attributes. No assay backing object is hashed.

A format compatibility fixture is the plain named list
`list(sample_id = enc2utf8("s\u00e9"), feature_ids = c("f1", "f2", "f3"),
values = c(0, 0.25, 0.75), missing = NA_real_, n = 3L)`.
Its expected SHA-256 under this recipe is fixed as
`0ebcc76956478405e0d59c09fd5ac022c6f231bd1677471c913c63132d574406`.
An unknown format or an environment that fails this compatibility check makes
fingerprint comparisons `not_checked` and validation incomplete; never report
a data change solely from incompatible encoding. The implementation must test
ordinary/ALTREP values, encoding, canonical NA/zero and this independent
expected digest. These fingerprints detect ordinary dependency edits, not
adversarial changes; manual snapshot editing remains unsupported.

## Worked examples and acceptance evidence

The companion [arithmetic script](../examples/002-personal-baseline-deviation.R)
checks these calculations directly; it calls no proposed analytical function
and supplies no benchmark or mock estimator.

For three features, select baseline counts `(8,2,0)`, `(60,40,0)`, `(7,3,0)`.
Their compositions are `(0.8,0.2,0)`, `(0.6,0.4,0)`, `(0.7,0.3,0)`, so the
reference is `(0.7,0.3,0)` despite different read totals. Its baseline diameter
is `0.2`. Counts `(4,4,2)` have composition `(0.4,0.4,0.2)` and deviation `0.3`.
This value alone gives no recovery classification.

Selecting only the first baseline gives deviation `0.4`, `single_sample`
support and NA diameter. Selecting the first and third gives reference
`(0.75,0.25,0)` and deviation `0.35`. Empty selection gives no reference and
NA deviation with `missing_baseline`. Removing the third feature and explicitly
starting a new analysis gives deviation `0.2`; an old three-feature result
must never be relabeled as that new calculation.

The bundled `recovery_examples$repeated_episodes` provides a second check:
select `s1` for `e1` and `s4` for `e2`. Both references have `single_sample`
support. Their reference compositions are `(1/3,2/3)` and `(7/15,8/15)`;
`s1`--`s5` deviations are `0, 2/21, 4/33, 0, 2/285`, and `s6` is excluded.
The second baseline at day 34 precedes event start 40 even though the origin
is event end 42. A hypothetical sample at day 41 has relative time -1 but is
ineligible as baseline. Selecting `s1` does not supply a baseline for `e2`.
The bundled `single_episode` likewise permits `s1` as a single-sample reference.

Implementation acceptance must cover these examples, duplicate times with
equal sample weighting, NA/negative/all-zero consumed columns, missing or
unknown requested IDs, source changes, removal/reordering of features and
baselines, absent-baseline episodes, owned-column collisions and unchanged
inputs on failure. Numerical comparisons use independently stated expected
values and an absolute tolerance of `1e-12` for these small examples.

## Alternatives and limits accepted by merging

- A single baseline is retained for reach and descriptive usefulness; requiring
  two would discard valid anchor comparisons without establishing sufficient
  variation evidence. Support reporting prevents that distinction being hidden.
- Equal sample weights are explicit and simple. Equal-time weighting, windows,
  replicate aggregation and longitudinal weighting require additional design;
  none is silently inferred from duplicate or irregular times.
- An arithmetic mean can be sensitive to atypical baselines and multimodality.
  A medoid would select an observed sample but introduce a different target
  and tie rules. Neither is implicitly substituted for the chosen mean.
- CLR/Aitchison or robust compositional methods merit later evaluation.
  Zero handling and fitted structure need their own contract; for example,
  [Martino et al. (2019)][martino] specify robust CLR with matrix completion.
  The current method makes no subcomposition-invariance or superiority claim.
- Population/donor references, shared cross-episode baselines, statistical
  fitting, confidence intervals, group comparisons and recovery rules remain
  outside this RFC. The reference describes selected measured compositions,
  not a latent healthy or undisturbed state.

Merging approves the interface, eligibility, numerical definitions, support
states, result ownership and dependency behavior above. Later implementation
PRs must supply meaningful tests and document limitations; they must not choose
unresolved alternative methods without a separately reviewed contract.

[dethlefsen]: https://pubmed.ncbi.nlm.nih.gov/20847294/
[david]: https://pmc.ncbi.nlm.nih.gov/articles/PMC4405912/
[bray]: https://vegandevs.github.io/vegan/reference/vegdist.html
[morton]: https://www.nature.com/articles/s41467-019-10656-5
[martino]: https://journals.asm.org/doi/10.1128/msystems.00016-19

[serialization]: https://cran.r-project.org/doc/manuals/r-release/R-ints.html#Serialization-Formats
[digest]: https://eddelbuettel.github.io/digest/man/digest/
