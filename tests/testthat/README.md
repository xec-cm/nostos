# Functional and integration tests

Registration and validation tests exercise the accepted RFC 001 through the
public `setup_recovery()` and `validate_recovery()` interfaces. The bundled
six-sample fixture has two explicit episodes and one excluded sample; expected
identities and coordinates come from the RFC's worked example.

`test-tse-preservation.R` combines registration, linked-tree subsetting,
reordering, new analysis registration and accessor-based edits. It complements
the focused contract tests without duplicating their invalid-input matrix.
The [preservation evidence map](../../dev/tse-preservation.md) describes the
operations covered and the limits of those checks.

Add tests alongside each implemented behavior. Future stages need their own
accepted examples for recovery outcomes and incomplete observations; registration
tests make no analytical recovery claims. Do not download cohorts in unit tests.
