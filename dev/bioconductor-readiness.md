# Bioconductor submission preparation

Assessed 2026-09-10 for #21/#22 in
[PR #40](https://github.com/xec-cm/recoverome/pull/40).
The maintainer authorized repository corrections and version **0.99.0**, replacing
unpublished 0.2.0. The corrected candidate passes local new-package and GitClone
checks without errors or warnings. Submission remains a separate maintainer
operation, including the source-layout decision below; acceptance is not claimed.

## Artifact and environment

Package-content commit: `18f74fc8d0cf7938bc83c0f7fc3795f40857219b`.
Archive: `recoverome_0.99.0.tar.gz`, 774,665 bytes; SHA-256:
`dbbea7988e33e15067281a3157c46384f8c7fc311b7259eb9b01c4b1668e032c`.
The [release preparation](releases/0.99.0.md) links implementation acceptance,
installation evidence and publication steps. R CMD check reports 0 errors,
0 warnings and 0 notes in about 2 minutes 20 seconds. Memory at cohort scale
has not been measured.

Local checks: macOS arm64, R 4.6.1, Bioconductor **3.23 release**, BiocCheck 1.48.1.
GitClone ran separately against a clean clone of the stated commit, without local
build products. The [official configuration](https://bioconductor.org/config.yaml)
on the assessment date maps R 4.6 to release 3.23 and devel 3.24. The
[0.99.0 CI matrix](https://github.com/xec-cm/recoverome/actions/runs/34457044281)
passed release on Linux/macOS/Windows and devel on Linux for the package-content
commit. Its R 4.6.1 / Bioconductor 3.24 devel run reports **0 errors, 0 warnings
and 5 notes** with BiocCheck 1.49.31; the optional funding-role note is absent in
that version. The final PR revision must also pass its required checks.

## Corrections applied

| Initial finding | Correction and evidence |
|:----------------|:------------------------|
| 0.2.0 rejected for a new submission | DESCRIPTION, NEWS, README, release plan and agent instructions now use 0.99.0. `dev/check-bioc.R` enables new-package checks for 0.99.x and selects the exact current-version archive. |
| Tracked RStudio project rejected by GitClone | Removed `recoverome.Rproj` from Git tracking and ignored it; retained the local file. Clean-clone check now has 0 errors and 0 warnings. |
| Submission vignette needed context and complete execution | Added introduction, scientific motivation, related methods/packages, author/date, installation and references; uses BiocStyle from Suggests. Core code is evaluated; optional tidy instructions remain in the external guide. |
| Assistance/provenance needed disclosure | Added installed `PROVENANCE.md`, linked from package help; retained PR and synthetic-data generation history. |
| Support-site Watched Tag missing | Maintainer added the tag; rerun confirmed package present in Watched Tags. Maintainer also confirmed bioc-devel subscription on 2026-09-10. |

The [documentation guidance](https://contributions.bioconductor.org/docs.html)
allows unevaluated installation code. All analytical vignette chunks run;
BiocStyle is used by the vignette, not an unused dependency. Provenance follows
the [AI/third-party policy](https://contributions.bioconductor.org/ai-policy-third-party.html):
substantial Codex assistance is disclosed and responsibility remains with the
maintainer. No analytical behavior was changed in this preparation.

## Remaining notes and their disposition

Local new-package BiocCheck: **0 errors, 0 warnings, 6 notes**.
Clean-clone BiocCheckGitClone: **0 errors, 0 warnings, 1 note**.
The [general guidelines](https://contributions.bioconductor.org/general.html)
require findings to be corrected or justified; automated checks do not decide
admission. Submit these explanations for reviewer consideration:

| Note | Disposition |
|:-----|:------------|
| Suggested `Classification` biocView | The method describes observed episode outcomes rather than fitting a classifier. Existing Microbiome/Metagenomics/TimeCourse terms describe its scope; do not add an automatically suggested term without semantic justification. |
| Optional `fnd` author role | No funding details were provided. Do not fabricate funding attribution; add it if applicable and supplied by the maintainer. |
| 29 functions over 50 lines | Length alone is not a defect. Long routines include a sequence of plot layers and cohesive evidence/relationship diagnostics. Existing reviews cover control flow and responsibilities; avoid mechanical fragmentation solely to silence this advisory. |
| 570 lines over 80 characters | The project permits readable lines up to 100 characters, with vertical long calls. Preserve readable expressions and documentation; justify necessary exceptions rather than blanket reformatting the package. |
| 2,459 indentation lines not multiples of four | Deliberate two-space style agreed with the maintainer and documented in `dev/r-style.md`; retain consistency. |
| Mailing-list subscription cannot be determined | The automated query requires administrator credentials. Maintainer explicitly confirmed subscription on 2026-09-10; the note is not evidence of non-subscription. |
| Optional CITATION absent (GitClone) | No package paper/preprint was supplied. Standard package citation uses DESCRIPTION metadata; do not invent a publication. Add a dedicated citation when an appropriate paper exists. |

Counts and note sets depend on the BiocCheck version. The hosted devel report
must be read on its own terms, not assumed identical to this local report.

## Requirements matched to evidence

| Area | Evidence and practical limit |
|:-----|:-----------------------------|
| Interoperability | TSE input/return, public accessors and DataFrame extraction; tests cover trees, identities and original analytical scope after selection. Introduction distinguishes recoverome from mia and vegan. |
| Documentation and data | Seven documented exports with runnable examples; installed end-to-end vignette and checkout README execute with independently checkable results. Bundled data are synthetic with generation source and documented structure. |
| Tests | 2,776 passing assertions, no failures/warnings/skips; 93.74% coverage, not a scientific-validity claim. Uses the layout described in the [testing guidance](https://contributions.bioconductor.org/tests.html). |
| Dependencies | Declared dependencies occur in the current CRAN/Bioconductor indexes; installation/check jobs test the resolved versions. BiocStyle is the only new dependency, in Suggests and used by the vignette. No Remotes or unused runtime dependency. |
| Name availability | No case-insensitive recoverome match in current CRAN, Bioconductor 3.23/3.24 software, CRAN Archive or the Bioconductor removed-package list on the assessment date. This is dated evidence, not a name reservation. |
| Size/resources | Archive below 10 MB; individual-file checks pass. Check duration below the 10-minute guideline. Selected sparse/delayed blocks may be realized in memory; larger-data memory use is unmeasured. |
| Maintenance | Named maintainer, contact/ORCID, license and issue tracker; Watched Tag verified and mailing-list membership confirmed by maintainer. Ongoing build-report/support response remains a maintainer commitment. |

Dependency placement and biocViews follow the
[DESCRIPTION guidance](https://contributions.bioconductor.org/description.html).
Name checks used [CRAN](https://cran.r-project.org/src/contrib/), its
[archive](https://cran.r-project.org/src/contrib/Archive/), Bioconductor package
indexes and the [removed-package list](https://bioconductor.org/about/removed-packages/).
Recheck availability and minimum-version compatibility at actual submission.

## Maintainer steps before actual submission

1. Merge the reviewed PR after the final required checks pass. Retain the checked
   source artifact, commit identity, checksum and reports.
2. Approve the **submission source layout**. The
   [submission instructions](https://contributions.bioconductor.org/bioconductor-package-submissions.html#submission)
   require the submitted repository's default branch to contain package code
   only. The development branch includes `.github/`, `dev/` and other tooling;
   `.Rbuildignore` protects the archive but does not remove tracked tooling.
   Prepare an isolated source branch/repository from the reviewed source inputs,
   keeping R code, help, tests, data, vignette sources, license and provenance;
   exclude development tooling and generated `inst/doc`. Review that tree and
   select it as the default branch of the repository actually submitted.
   Do not replace the existing development default branch or discard its CI as
   an incidental release-preparation change. No branch/account change is made here.
3. Run build/check, new-package BiocCheck and clean GitClone on that exact source
   revision in the current Bioconductor devel environment. Retain and explain
   remaining notes, including the deliberate style choices above. Resolve any
   new substantive finding before submitting.
4. Confirm reachable maintainer email, continuing maintenance/support commitment,
   and any applicable funding/citation details. Include assistance provenance and
   note explanations in the submission. The maintainer opens and manages it.

The [version policy](https://contributions.bioconductor.org/versionnum.html)
starts new submissions at 0.99.0; later development patches and release-cycle
versions follow Bioconductor conventions. A version number, merged preparation
PR or published GitHub prerelease does not itself constitute submission.

## Reproduce submission-specific checks

After building, `Rscript --vanilla dev/check-bioc.R` runs new-package mode for
0.99.x. For GitClone, use a separate fresh R session and a clean clone of the
recorded commit:

```r
BiocCheck::BiocCheckGitClone(
  "path/to/clean/recoverome-clone",
  `quit-with-status` = FALSE
)
```

The advisory script exit status alone is not a pass: inspect the recorded error,
warning and note counts. Refresh this dated record for the actual submission.
