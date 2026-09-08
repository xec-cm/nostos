# Repository instructions

recoverome is an experimental R package. The current version is a scaffold;
planned analysis functions must not be described as implemented.

## Scope and changes

- Read `dev/architecture.md` before changing data contracts or public APIs.
- Preserve user changes and unrelated work. Keep edits focused on the task.
- Do not add analytical stubs, placeholder return values, or fabricated
  benchmark results. Implement useful behavior before exporting it.
- Keep planned and implemented functionality clearly separated in docs.
- Do not add runtime libraries until implemented code uses them.
- Do not make Git commits, create branches, or publish changes unless the task
  authorizes those actions.

## R implementation

- Use `Rscript --vanilla` for reproducible command-line execution.
- Use public accessors for TSE, SummarizedExperiment, and S4Vectors objects.
  Do not read or write S4 slots directly.
- The planned setup/add functions accept and return a TSE. Preserve unrelated
  assays, identities, and user metadata.
- Keep analysis records in named metadata analyses and sample annotations in
  `colData()` columns prefixed with `rec_<analysis>_`.
- Preserve original analysis scope after filtering. Never silently refit,
  rebuild a reference, or recompute a historical outcome.
- Validate identities and dependencies explicitly. Do not rely on positional
  matching or implicit recycling.

## Documentation and checks

- Write project documentation in English and use readable line lengths.
- Edit `README.Rmd`; regenerate `README.md` rather than editing it directly.
- Mark proposed API examples with `eval=FALSE`. Executed vignette chunks must
  use available functions and make no unsupported analytical claims.
- Use meaningful tests for implemented behavior and failure modes. Do not add
  tests that merely encode placeholder outputs.
- Run checks appropriate to the change and report their actual outcomes. Run
  the package check before the Bioconductor check, which uses its built
  package artifact:

```sh
Rscript --vanilla dev/check-package.R
Rscript --vanilla dev/check-generated.R
Rscript --vanilla dev/check-bioc.R
```

The Bioconductor check is informative at this stage. Its presence does not
mean the package has been submitted to or accepted by Bioconductor. Resolve or
report relevant findings; never claim that an unrun check passed.
