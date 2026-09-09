test_that("rule input and repeated calls fail atomically with public call attribution", {
  tse <- recovery_parent()
  invalid <- list(NULL, numeric(), list(), observed_rule()[1:3],
                  c(observed_rule(), list(extra = 1)))
  for (field in names(observed_rule())) {
    for (bad in list(NA_real_, Inf, TRUE, numeric(), c(1, 2), "1", structure(1, class = "Date"))) {
      rule <- observed_rule()
      rule[[field]] <- bad
      invalid[[length(invalid) + 1L]] <- rule
    }
  }
  for (field in names(observed_rule())) {
    rule <- observed_rule()
    rule[[field]] <- -1
    invalid[[length(invalid) + 1L]] <- rule
  }
  for (rule in invalid) expect_outcome_error(tse, rule)
  expect_outcome_error(tse, analysis_id = NULL)
  expect_outcome_error(tse, analysis_id = c("a", "b"))
  expect_outcome_error(tse, analysis_id = "unknown")
  condition <- tryCatch(add_recovery(tse, "antibiotic", list()), error = identity)
  expect_match(deparse(conditionCall(condition)), "add_recovery")
  complete <- add_recovery(tse, "antibiotic", observed_rule())
  expect_outcome_error(complete)
})

test_that("new outcomes require unchanged complete parents and the realized sample scope", {
  tse <- recovery_parent()
  changed <- corrupted <- unsupported <- expanded <- tse
  SummarizedExperiment::assay(changed, "counts")[, "s3"] <- c(14, 2)
  SummarizedExperiment::colData(corrupted)$rec_antibiotic_deviation[2] <- 0.8
  record <- registration_record(unsupported)
  record$deviation$provenance$fingerprint_format <- "unknown"
  S4Vectors::metadata(unsupported)$recoverome$analyses$antibiotic <- record
  # Add an identity rather than silently enrolling it in the old deviation scope.
  expanded <- tse[, c(seq_len(ncol(tse)), 2L)]
  colnames(expanded)[ncol(expanded)] <- "added"
  for (input in list(changed, corrupted, unsupported, expanded, tse[, -1], tse[, -3], tse[1, ])) {
    expect_outcome_error(input)
  }
  registered <- register_fixture(recovery_fixture())
  expect_outcome_error(registered)
  expect_outcome_error(add_reference(registered, "antibiotic", "b1", assay = "counts"))

  reference <- add_reference(
    registered, "antibiotic", "b1", assay = "counts", features = "feature_a"
  )
  single_feature <- add_deviation(reference, "antibiotic")
  outcome <- add_recovery(single_feature[1, ], "antibiotic", observed_rule())
  expect_identical(
    registration_record(outcome)$recovery$episodes$status,
    "no_detected_perturbation"
  )
})

test_that("empty references and empty realized scopes retain explicit not-evaluable outcomes", {
  missing <- recovery_parent(reference = character())
  out <- add_recovery(missing, "antibiotic", observed_rule())
  expect_identical(registration_record(out)$recovery$episodes$reason, "missing_baseline")
  expect_identical(registration_record(out)$recovery$episodes$coverage, "reaches_horizon")

  registered <- register_fixture(recovery_fixture())
  empty_reference <- add_reference(registered, "antibiotic", character(), assay = "counts")
  empty_deviation <- add_deviation(empty_reference[, FALSE], "antibiotic")
  empty <- add_recovery(empty_deviation, "antibiotic", observed_rule())
  record <- registration_record(empty)$recovery
  expect_identical(record$episodes$reason, "missing_baseline")
  expect_identical(record$episodes$coverage, "none")
  expect_identical(record$episodes$n_window_visits, 0L)
  expect_true(all(lengths(record$evidence$episode_1) == 0L))
  expect_true(validate_recovery(empty)$summary$validation_complete)
})
