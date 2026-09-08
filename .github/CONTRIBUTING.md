# Contributing to recoverome

Thank you for contributing. recoverome 0.1.0 is an experimental scaffold;
recovery analysis functions are not implemented yet. Contributions should
make a concrete, reviewable improvement and distinguish implemented behavior
from proposals.

## Before changing the interface

Read [the architecture contract](https://github.com/xec-cm/recoverome/blob/devel/dev/architecture.md)
and the repository's
`AGENTS.md`. Discuss substantial API or statistical changes in an issue before
investing in an implementation. State the intended user question, estimand,
input requirements, and limitations.

The development branch is `devel`. Keep changes focused and preserve unrelated
work. New runtime dependencies should support an implemented feature rather
than a hypothetical future need.

## Local development checks

Run checks from the repository root with a clean R session in the order shown.
The package check must run before the Bioconductor check because the latter
uses the package artifact built by the former:

```sh
Rscript --vanilla dev/check-package.R
Rscript --vanilla dev/check-generated.R
Rscript --vanilla dev/check-bioc.R
```

The Bioconductor check is informative during this early development stage;
it does not imply that the package is submitted to or accepted by
Bioconductor. Review its findings and report relevant limitations in a pull
request. Do not describe checks that were not run as passing.

Edit `README.Rmd`, not the generated `README.md`. Keep generated documentation
in sync using the project's generation workflow and verify it with
`dev/check-generated.R`. Use the roxygen2 version pinned in
`Config/Needs/quality` in `DESCRIPTION` when regenerating documentation so
local output matches CI.

## Code and documentation

- Use TSE and SummarizedExperiment accessors rather than direct S4 slot access.
- Preserve unrelated assays and user metadata.
- Keep named analyses separate and make result provenance explicit.
- Preserve the original scope of historical analyses after filtering; never
  silently refit or reclassify them.
- Add meaningful tests for implemented contracts and failure modes. Do not
  add analytical stubs or tests that merely assert placeholder values.
- Mark proposed API examples as non-executable. Vignettes must not imply that
  a planned function already exists.
- Keep documentation in English and wrap prose to a readable line length.

## Reporting a problem

Use the issue template to describe the observed behavior, expected behavior,
and a small reproducible example. Include package and R versions when relevant.
Use simulated or de-identified data and omit private participant information.

For methodological proposals, explain the observational assumptions and the
evidence that would validate the method. Do not claim benchmark performance
without reproducible results and a clear comparison.

## Pull requests

Explain the problem, the resulting behavior, and how the change was checked.
Identify generated files and any checks that could not run. All contributions
are covered by the repository's license and
[Code of Conduct](https://github.com/xec-cm/recoverome/blob/devel/CODE_OF_CONDUCT.md).
