# recoverome (development version)

- Add `setup_recovery()` to register named analyses with explicit sample
  membership, episode and event tables, and declared numeric time coordinates.
- Store normalized registration tables, original sample and feature scope,
  and provenance in TSE metadata while preserving existing container content.
- Add executable registration and historical-scope examples to the README
  and introductory vignette. The standalone validator and analytical stages
  remain planned.

# recoverome 0.1.0

- Establish an experimental package scaffold and development infrastructure.
- Document the proposed TSE-based recovery workflow and seven-function API.
- Define intended contracts for named analyses, sample annotations, provenance,
  and preservation of historical analysis scope after filtering.
- Add an introductory vignette with an executable example of the input TSE.

Recovery analysis functions and statistical fitting are not implemented in
this version.
