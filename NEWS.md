# recoverome 0.99.0

Experimental MVP and initial Bioconductor submission candidate. This replaces
the unpublished 0.2.0 target by explicit maintainer decision. Publication and
submission remain separate decisions; this heading does not claim acceptance.

## Submission preparation

- Use BiocStyle for the executable vignette, with an introduction, related-method
  references, installation instructions and session information. Keep optional
  tidy recipes in the external integration guide.
- Keep RStudio project settings local and record coding-agent provenance in the
  installed package. Document remaining account obligations and justified notes.

## Personal-baseline workflow

- Register independent named analyses with `setup_recovery()`, explicit sample
  membership, episodes, events and numeric time coordinates in a
  TreeSummarizedExperiment (TSE).
- Attach personal references with `add_reference()` from explicitly selected
  baseline samples. Record equal-sample mean compositions, support, descriptive
  baseline diameter and input provenance.
- Calculate Bray--Curtis sample deviations against fixed episode profiles with
  `add_deviation()`, retaining computed, missing-baseline and excluded statuses.
- Attach observed episode outcomes with `add_recovery()` under an explicit
  threshold, persistence, maximum-gap and horizon rule. Preserve first return,
  confirmation, later rebound, supporting observations and separate coverage.

## Results and history

- Diagnose registration, analytical dependencies and historical scope with
  `validate_recovery()` without modifying or recomputing the analysis.
- Extract sample or episode DataFrame views with `recovery_results()`, separating
  result availability from current validation and retaining context in metadata.
- Display observations and saved evidence with `plot_recovery()`, returning
  customizable ggplot2 objects. Expose original gaps, incomplete follow-up,
  changed inputs and missing current evidence after filtering.
- Preserve TSE content and original scope after filtering or reordering. New
  definitions require a new analysis name; existing stages are not overwritten.
- Provide actionable cli messages with typed conditions and affected identities.

## Examples and scope

- Bundle three small synthetic `recovery_examples` cases, generated from source
  and reused in tests, help and the executable end-to-end README and vignette.
- Verify bounded optional sample filtering, reordering and annotation mutation
  through tidySingleCellExperiment. Document its annotation-metadata limitations;
  no tidy adapter is required for the core workflow.
- This is a descriptive, experimental API. One baseline does not establish
  stability; observed confirmation does not imply continuous or clinical recovery.
  Statistical fitting, group comparisons and recovery-time uncertainty methods
  are outside this release.

# recoverome 0.1.0

- Establish an experimental package scaffold and development infrastructure.
- Document the proposed TSE-based recovery workflow and seven-function API.
- Define intended contracts for named analyses, sample annotations, provenance,
  and preservation of historical analysis scope after filtering.
- Add an introductory vignette with an executable example of the input TSE.

Recovery analysis functions and statistical fitting are not implemented in
this version.
