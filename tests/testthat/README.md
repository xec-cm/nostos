# Functional tests

Add `test-*.R` files alongside each implemented behavior. This initial package
does not implement analytical functions, so no synthetic passing tests are
included. The test runner and coverage workflow report that absence explicitly.

Future tests should protect sample identity, TSE preservation, result scope,
candidate versus confirmation dates, and incomplete longitudinal observations.
Use small deterministic fixtures; do not download cohorts during unit tests.
