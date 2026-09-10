# Functional and integration tests

Registration and validation tests exercise the accepted RFC 001 through the
public `setup_recovery()` and `validate_recovery()` interfaces. The bundled
six-sample fixture has two explicit episodes and one excluded sample; expected
identities and coordinates come from the RFC's worked example.

`test-tse-preservation.R` combines registration, linked-tree subsetting,
reordering, new analysis registration and accessor-based edits. It complements
the focused contract tests without duplicating their invalid-input matrix.
The [preservation evidence map](../../dev/README.md#integration-evidence-map) describes the
operations covered and the limits of those checks.

Recovery tests exercise the accepted RFC 003 trajectories and observation rule.
`test-recovery-history.R` contrasts short follow-up with a filtered completed
analysis, while `test-recovery-multi-analysis.R` checks distinct histories and
diagnostics in the same TSE. The [recovery evidence map](../../dev/README.md#integration-evidence-map)
links the acceptance criteria to these tests and the existing calculation cases.

Add tests alongside each implemented behavior. Registration tests make no
analytical recovery claims. Do not download cohorts in unit tests.

Optional tidy checks live in `dev/tests/test-tidy.R` and run explicitly through
`dev/check-tidy.R`, outside the mandatory package suite. See the
[assessment and limitations](../../dev/tidy-interoperability.md), including the
separate full core test/package check with adapters unavailable.

Error assertions specify the relevant condition class and component. Repeated
invalid-type matrices are consolidated only where the same normalizer is used;
each input field retains a dispatch check. `test-reference-contracts.R` protects
first-error behavior alongside independent cumulative diagnostics. Optional
[execution-cost measurements](../../dev/performance/) run outside this suite.
