# Functional tests

Registration tests exercise the accepted RFC 001 through `setup_recovery()`.
The six-sample fixture has two explicit episodes and one excluded sample;
its expected identities and coordinates come from the RFC's worked example.
Deterministic trees also exercise preservation of TSE links and annotations.

Add tests alongside each implemented behavior. Future stages need their own
accepted examples for recovery outcomes and incomplete observations; registration
tests make no analytical recovery claims. Do not download cohorts in unit tests.
