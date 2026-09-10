# nostos 0.99.0

- Renamed the installable package from `recoverome` to `nostos`. Public function
  names, saved metadata, fingerprint formats and condition classes are unchanged.
  Use `nostos::` for calls; existing analyses require no refitting or migration.
- Moved the repository and documentation site to `xec-cm/nostos` and
  `https://xec-cm.github.io/nostos/`; updated current installation and support links.
- Added the approved NOSTOS watercolor logo, PNG browser icons and the
  maintainer-selected Minty documentation theme.

- Shortened onboarding and added installed guides for input preparation,
  filtering/history/validation, and a real antibiotic-exposure example.
- Added `dethlefsen2008`, all 5,670 V3 refOTUs and 18 samples from the published
  normalized abundance table, with original dates and source attribution.
- Recorded a prespecified scientific assessment with independent arithmetic,
  complete baseline/rule/sampling scenarios, and explicit interpretation limits.
- Consolidated developer evidence and check every installed vignette from the
  built package. Recorded the accepted sensitivity and diagnostic-plot contracts;
  both extensions are implemented below.

Experimental MVP and initial Bioconductor submission candidate. This replaces
the unpublished 0.2.0 target by explicit maintainer decision. Publication and
submission remain separate decisions; this heading does not claim acceptance.

## Rule sensitivity

- Added `recovery_sensitivity()` and `plot_sensitivity()` for explicitly supplied
  recovery rules. Results retain every scenario/episode and provenance while
  preserving the original TSE, including existing recovery outcomes.
- Changed or unavailable historical inputs remain visible as unevaluable
  scenarios. The plot distinguishes them from evaluated missing-baseline or
  overlapping-event outcomes; no preferred rule is selected.

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

## Diagnostic plots

- Add `plot_reference()`, `plot_sampling()` and `plot_recovery_overview()` as
  ordinary editable ggplots. Distinguish recorded baseline support from available
  distances, original observation gaps from removed samples, and saved milestones
  from their current evidence availability. Preserve historical times and
  outcomes, show source-validation context, and handle empty scope explicitly.
- Add an offline diagnostic plotting guide with executable synthetic examples.
  The existing reference, deviation and recovery definitions are unchanged.

# nostos 0.1.0

- Establish an experimental package scaffold and development infrastructure.
- Document the proposed TSE-based recovery workflow and seven-function API.
- Define intended contracts for named analyses, sample annotations, provenance,
  and preservation of historical analysis scope after filtering.
- Add an introductory vignette with an executable example of the input TSE.

Recovery analysis functions and statistical fitting are not implemented in
this version.
