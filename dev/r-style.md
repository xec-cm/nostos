# R style for recoverome

Use this guide alongside [AGENTS.md](../AGENTS.md), the accepted RFCs, and the
[development workflow](development-workflow.md). It guides implementation;
it does not change public contracts, statistical choices, or dependencies.
Preserve the maintainer's edits and the surrounding code's consistent style.

## Evidence and attribution

The historical reference is maintainer-authored `dar` code inspected on
2026-09-09, using a cutoff of 2026-06-09. Sources were read with `git show`;
`git blame` checked authorship instead of assuming every old line was written
by the maintainer. No working-tree changes in `dar` were used as history.

- [Filtering interface and helpers][filter]: snapshot `5826db6` (2025-10-28).
  The relevant lines trace to xec-cm's `5bf80275` and `72bff229` (2023-11-29).
- [Named transformations and final returns][misc]: snapshot `ff68616`
  (authored 2025-02-10, committed 2025-03-15). The illustrated helper traces
  mainly to xec-cm's `42d4438a` (2022-05-16).
- [Long signatures and separated stages][corncob]: `d3a4b0f` (2024-04-05),
  authored by xec-cm, which introduced this implementation.
- [Actionable `rlang` errors][errors]: the error lines trace to xec-cm's
  `c01ce937` (2022-06-13), visible in snapshot `ff68616`.
- [Aggregated validation findings][validation]: snapshot `5826db6`; the
  aggregation and `rlang::abort()` trace to xec-cm's `8c1d61c1` (2022-05-06).

Do not attribute the 2026 bot refactors to the maintainer's personal style.
In particular, `e198f73` changed S4 workflow methods to functions and
`b85358f` introduced `cli::cli_abort()` and `dar_error_*` classes on 2026-03-13.
The April snapshot already includes these changes. Current maintainer edits
to `recoverome` also favor vertical setup arguments and separated blocks;
these are additional local guidance, not historical permalink evidence.

## Observed historical style

### Formatting and names

- Use two spaces for indentation, `<-` for assignment, and spaces around
  operators and after commas. Remove trailing whitespace.
- Expand long signatures and calls vertically, with one argument per line.
  Align continuation arguments consistently; keep short calls compact when
  they are easy to read. Do not expand every trivial expression mechanically.
- Separate meaningful phases with blank lines: input checks, preparation,
  calculation, and result construction should be easy to distinguish.
- Use `snake_case` for functions, parameters, and local variables. Follow the
  existing `.recovery_*` convention for internal recoverome helpers.
- Prefer descriptive names such as `sample_ids` or `included_samples` over
  numbered checks or opaque abbreviations. Preserve an external API's own
  argument names when passing arguments to it.

### Function structure and control flow

- Keep public functions readable as a sequence of meaningful operations.
  Extract helpers when they own a distinct responsibility, remove meaningful
  repetition, or make a contract independently understandable.
- Organize code into phases with useful intermediate values. Do not create
  a helper for every expression or turn a short operation into a framework.
- Use ordinary `if` blocks and loops when their flow is clearest. Early
  returns are appropriate for genuine guard cases.
- Prefer the last expression as the normal return value. Use `return()` for
  early exits; use an invisible return only when the function's contract
  calls for it.
- Comments should explain intent, assumptions, or a non-obvious constraint.
  Brief phase comments can help a long operation; avoid narrating each line.

### Transformations and dependencies

- Use pipelines when they clarify a sequence of transformations. Give long
  or reused intermediate results meaningful names; do not force everything
  into one chain or introduce a pipe for a trivial accessor call.
- Historical implementation uses `%>%`, while examples also use `|>`.
  That supports readable composition, not an exclusive pipe preference.
- Qualify external functions with `package::function` unless the package
  already imports them intentionally. Do not call `library()` inside package
  functions or rely on packages attached in an interactive session.
- Preserve the purpose of helpers and transformations, not the historical
  choice of a dependency for every operation.

### Documentation and messages

- Keep roxygen documentation beside public functions. Explain accepted
  inputs, output, side effects or preservation, and relevant failure modes.
  Include small examples that demonstrate the actual contract.
- Mark internal helpers as internal where documentation is useful. Avoid
  duplicating a public contract across many helpers or documenting obvious
  assignments in prose.
- Historical code uses `rlang::abort()`, with a main problem and named bullets
  containing details or a concrete remedy. Recoverome now uses `cli` at the
  maintainer's explicit request; see the adaptations below.
- State which argument or component failed, what was expected, and useful
  offending identifiers. Keep informational messages distinct from errors.

## Recoverome adaptations and quality guardrails

The following are deliberate project choices. They must not be presented as
proof of historical author preferences.

- The maintainer explicitly reinforced shallow control flow on 2026-09-09.
  Aim for at most two nested control-flow blocks in ordinary code. At a third
  level, reconsider the responsibilities and use a guard, `next`, or a cohesive
  helper where that makes the flow clearer. Explain any necessary deeper case
  during review; this is a design expectation, not an arbitrary CI threshold.
- Keep independent checks in consecutive blocks. A helper should own a clear
  result or responsibility; moving an unchanged nested block into a helper
  does not resolve its complexity. Avoid helpers for trivial expressions,
  callback frameworks, or compressed boolean expressions used only to hide
  branching. The public function should expose the main stages of its work.
- Before an early return, account for shared diagnostics and finalization.
  A diagnostic function must retain known global failures and all independent
  findings that remain checkable. Check raw types once and reuse normalized
  values and common accessors throughout the relevant operation.
- Independent review must inspect the final control flow as well as behavior.
  Treat unnecessary deep nesting, repeated interpretation of inputs and
  functions mixing unrelated responsibilities as actionable review findings,
  even when the tests, coverage and CI are satisfactory.
- Keep the accepted TSE interface and public accessors. Do not copy `dar`'s
  recipe classes, workflow dispatch, direct S4 slot access, or slot writes.
  Preserve unrelated content and historical scope as the RFC requires.
- Prefer native `|>` for a new pipeline that needs no special pipe behavior.
  Do not add `magrittr`, `dplyr`, or another runtime dependency just to imitate
  old formatting. Base R is appropriate when it expresses the operation well.
- Use `cli::cli_abort()` through the small `.recovery_abort()` helper for
  package errors, as requested by the maintainer on 2026-09-09. This explicit
  preference takes precedence over the historical `rlang` examples. Use
  `cli::cli_warn()` or `cli::cli_inform()` only for meaningful warnings or
  messages. Keep error wording close to the failing check.
- Write templates such as `"{.arg {label}} must be a numeric vector."` instead
  of assembling messages with `paste0()`. Use semantic markup for arguments,
  fields and values, and named bullets for details. Interpolate user values
  into a fixed template so braces inside an ID remain literal data.
- Pass `.envir` from the failing helper for local glue expressions; pass the
  public call separately for attribution. These environments have different
  purposes. Base `parent.frame()` and `environment()` suffice here; no direct
  `rlang` or `glue` dependency is needed for these calls.
- Package errors inherit from `recoverome_error`, with input, namespace, or
  collision subclasses as appropriate. Capture the public call and forward
  it explicitly through validation helpers so the error identifies the
  user's operation. These condition classes and call handling are deliberate
  enhancements to the historical direct `rlang::abort()` pattern.
- Keep complete offending IDs in condition data. Cap the displayed list when
  necessary and indicate omitted items; do not truncate the machine-readable
  details just to shorten a message.
- Do not catch arbitrary errors and continue with an empty or success-shaped
  result. If a future operation must rethrow a lower-level error with context,
  preserve that condition as its parent instead of retaining only its text.
- Check scalar type, length, missingness, and allowed values before using
  them in control flow. Use `&&` and `||` for scalar guards. Avoid ambiguous
  names that can resolve to either a data column or a function parameter.
- Check input types and normalize them once. Helpers receiving normalized
  tables should trust those types and only check the relationships they own.
  Use the container's own validity checks for structural invariants; keep
  identity, membership and temporal rules specific to recoverome explicit.
  Do not repeat equivalent checks merely to make every helper defensive.
- Do not construct executable text with `parse()`/`eval()` or use `<<-` to
  update a caller's object. Do not silently change global options, install
  packages, or leave a changed parallel plan behind.
- Do not adopt `checkmate`, `map_dfr()`, roxytest, or a new test framework by
  imitation. Use current dependencies and tests unless implemented behavior
  provides a separately justified reason to change them.
- Historical trailing spaces, inconsistent compact blocks, vague messages,
  lost error causes, and documentation mismatches are not style requirements.
  Test behavior and edge cases; never preserve an obvious bug for resemblance.

## Formatting illustration

This small example illustrates layout and control flow only. It is not a
new recoverome function or a proposal for a public API.

```r
format_labels <- function(values,
                          prefix = "",
                          separator = ", ") {
  if (length(values) == 0L) {
    return("")
  }

  labels <- paste0(prefix, values)

  paste(labels, collapse = separator)
}
```

Before finishing a change, check that the code reads in meaningful phases,
the names expose its purpose, and helpers simplify rather than fragment it.
Verify the behavior with the repository's existing checks; cosmetic similarity
does not replace tests, accepted contracts, or review.

[filter]: https://github.com/MicrobialGenomics-IrsicaixaOrg/dar/blob/5826db6366b8766e42eb9a6b7155103273df4909/R/filter_by_prevalence.R#L43
[misc]: https://github.com/MicrobialGenomics-IrsicaixaOrg/dar/blob/ff68616dba6abe2d47663fb6a939b23c4407105a/R/misc.R#L49
[corncob]: https://github.com/MicrobialGenomics-IrsicaixaOrg/dar/blob/d3a4b0fd81c6c8358641550f0480483b26c0e54e/R/corncob.R#L174
[errors]: https://github.com/MicrobialGenomics-IrsicaixaOrg/dar/blob/ff68616dba6abe2d47663fb6a939b23c4407105a/R/misc.R#L253
[validation]: https://github.com/MicrobialGenomics-IrsicaixaOrg/dar/blob/5826db6366b8766e42eb9a6b7155103273df4909/R/read_data.R#L146
