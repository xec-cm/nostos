# recoverome (development version)

- Document and verify the distinction between incomplete follow-up, filtered
  historical recovery and a new subset analysis, including independent named
  analyses and missing observation evidence. The observed rule is unchanged.

- Add `add_recovery()` for the accepted observed-run rule, with explicit threshold,
  persistence, maximum gap and horizon. Store episode outcomes, visit evidence,
  separate follow-up coverage and full parent fingerprints without new sample
  columns or changes to parent data.
- Extend `validate_recovery()` to recovery records, their parent chain and
  historical inputs, preserving independent findings without recomputing outcomes.
  Add the small synthetic `observed_recovery` example and executable documentation.

- Extend `validate_recovery()` to reference and deviation records, comparing
  consumed sources, stored parent fingerprints and authoritative sample outputs.
  Report changed dependencies, unavailable historical inputs and limited baseline
  support without refitting, repairing or changing the TSE.
- Preserve registration-only validation and the version-1 report tables. Known
  reference/deviation stages are now checked; unsupported schemas or fingerprint
  formats remain incomplete, with independently detectable findings retained.

- Add `add_deviation()` to calculate Bray--Curtis dissimilarities against fixed
  personal references, with explicit computed, missing-baseline and excluded
  sample statuses. Store results by sample identity in owned `colData()` columns.
- Check required reference dependencies before new deviation calculations and
  record realized scope and source/result fingerprints. Later filtering preserves
  historical results; analytical diagnostics in `validate_recovery()` follow
  separately in issue #12.

- Add `add_reference()` for explicit personal baseline selection, equal-sample
  mean composition profiles, descriptive support and baseline diameter.
- Record realized baseline identities, selected assay/features and canonical
  input fingerprints while preserving the TSE and other named analyses.
  References remain historical after filtering; repeated additions do not
  overwrite earlier results. Reference-stage validation follows separately.

- Add `validate_recovery()` for registration structure, consumed metadata
  dependencies, and historical scope, returning typed diagnostic tables without
  changing the input or inspecting assay values.

- Add `setup_recovery()` to register named analyses with explicit sample
  membership, episode and event tables, and declared numeric time coordinates.
- Store normalized registration tables, original sample and feature scope,
  and provenance in TSE metadata while preserving existing container content.
- Signal recoverome input, namespace and collision errors with `cli::cli_abort()`,
  interpolated messages, typed conditions, public-call context and structured
  affected identifiers.
- Bundle two small synthetic `recovery_examples` datasets with reproducible
  source generation, shared by registration tests, function help and vignettes.
- Add executable registration and historical-scope examples to the README
  and introductory vignette.

# recoverome 0.1.0

- Establish an experimental package scaffold and development infrastructure.
- Document the proposed TSE-based recovery workflow and seven-function API.
- Define intended contracts for named analyses, sample annotations, provenance,
  and preservation of historical analysis scope after filtering.
- Add an introductory vignette with an executable example of the input TSE.

Recovery analysis functions and statistical fitting are not implemented in
this version.
