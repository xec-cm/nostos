test_that("explicit rules preserve the TSE and match separate complete runs", {
  parent <- recovery_parent()
  tse <- add_recovery(parent, "antibiotic", observed_rule())
  original <- serialize(tse, NULL)
  rules <- sensitivity_rules()
  result <- recovery_sensitivity(tse, "antibiotic", rules)
  expect_s4_class(result, "DataFrame")
  expect_identical(serialize(tse, NULL), original)
  expect_identical(result$scenario_id, rules$scenario_id)
  expect_identical(result$status, c("confirmed_return", "unconfirmed_return",
                                    "no_observed_return", "unconfirmed_return"))
  expect_identical(result$confirmation_time, c(6, NA_real_, NA_real_, NA_real_))
  expect_identical(result$rebound_time, c(8, NA_real_, NA_real_, NA_real_))
  expect_identical(result$candidate_time, c(2, 2, NA_real_, 2))
  expect_identical(result$evaluation_state, rep("evaluated", 4))
  context <- S4Vectors::metadata(result)$recoverome_sensitivity
  expect_identical(context$analysis$evidence, registration_record(tse)$recovery$evidence)
  for (i in seq_len(nrow(rules))) {
    rule <- as.list(rules[i, -1L])
    independent <- add_recovery(parent, "antibiotic", rule)
    expected <- recovery_results(independent, "antibiotic")
    fields <- intersect(names(expected), names(result))
    expect_equal(as.list(result[i, fields]), as.list(expected[, fields]))
    expect_identical(context$evidence[[i]], registration_record(independent)$recovery$evidence)
  }
})

test_that("order and duplicate rule values remain explicit scenarios", {
  tse <- recovery_parent()
  rules <- sensitivity_rules()[c(2, 1, 1), ]
  rules$scenario_id <- c("z", "a", "replicate {rule}")
  result <- recovery_sensitivity(
    tse[, rev(colnames(tse))], "antibiotic", S4Vectors::DataFrame(rules)
  )
  expect_identical(result$scenario_id, rules$scenario_id)
  expect_identical(result$status, c("unconfirmed_return", "confirmed_return", "confirmed_return"))
  expect_identical(result$confirmation_time, c(NA_real_, 6, 6))
})

test_that("all original episodes remain represented after input loss or changes", {
  tse <- register_fixture(registration_fixture(trees = TRUE))
  tse <- add_reference(tse, "antibiotic", c("s1", "s4"), assay = "counts")
  tse <- add_deviation(tse, "antibiotic")
  selected <- tse[, 1:3]
  before <- serialize(selected, NULL)
  result <- recovery_sensitivity(selected, "antibiotic", sensitivity_rules()[1:2, ])
  expect_identical(serialize(selected, NULL), before)
  expect_identical(result$episode_id, rep(c("e1", "e2"), 2))
  expect_identical(result$subject_id, rep("p1", 4))
  expect_identical(result$current_present, rep(c(TRUE, FALSE), 2))
  expect_identical(result$evaluation_reason, rep("historical_inputs_unavailable", 4))
  expect_true(all(is.na(result$status) & is.na(result$last_observed_time)))
  expect_identical(result$n_baseline_samples, rep(1L, 4))
  evidence <- S4Vectors::metadata(result)$recoverome_sensitivity$evidence
  expect_identical(evidence, list(primary = NULL, short_gap = NULL))

  SummarizedExperiment::assay(selected, "counts")[, 1] <-
    SummarizedExperiment::assay(selected, "counts")[, 1] * 2
  changed <- recovery_sensitivity(selected, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(changed$evaluation_reason, rep("inputs_changed", 2))
  empty <- recovery_sensitivity(tse[, FALSE], "antibiotic", sensitivity_rules()[1, ])
  expect_identical(empty$current_present, c(FALSE, FALSE))
  expect_identical(empty$episode_id, c("e1", "e2"))
})

test_that("unavailable scenarios do not copy historical recovery or invoke the classifier", {
  tse <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  testthat::local_mocked_bindings(.recovery_episode_outcome = function(...) {
    stop("The classifier must not run without its original inputs.")
  })
  result <- recovery_sensitivity(tse[, colnames(tse) != "s3"], "antibiotic", sensitivity_rules())
  expect_true(all(is.na(result$confirmation_time)))
  expect_identical(result$evaluation_reason, rep("historical_inputs_unavailable", 4))
})

test_that("missing baselines and absent window observations are evaluated outcomes", {
  missing <- recovery_parent(reference = character())
  result <- recovery_sensitivity(missing, "antibiotic", sensitivity_rules())
  expect_identical(result$evaluation_state, rep("evaluated", 4))
  expect_identical(result$status, rep("not_evaluable", 4))
  expect_identical(result$reason, rep("missing_baseline", 4))
  expect_true(all(is.na(result$evaluation_reason)))
  late <- recovery_parent(recovery_fixture(12, .75))
  result <- recovery_sensitivity(late, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(result$reason, "no_observations_in_window")
  expect_identical(result$coverage, "reaches_horizon")
})

test_that("tied samples and exact boundaries use the existing observation semantics", {
  tse <- recovery_parent(recovery_fixture(c(0, 2, 2, 4, 6, 8), c(.75, .25, .5, .25, .25, .25)))
  result <- recovery_sensitivity(tse, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(result$candidate_time, 4)
  expect_identical(result$confirmation_time, 8)
  evidence <- S4Vectors::metadata(result)$recoverome_sensitivity$evidence$primary$episode_1
  expect_identical(evidence$confirmation_run, c("s4", "s5", "s6"))
})

test_that("unused features and new identities do not alter the realized analysis", {
  tse <- recovery_parent(features = "feature_a")
  result <- recovery_sensitivity(tse[1, ], "antibiotic", sensitivity_rules()[1, ])
  expect_identical(result$evaluation_state, "evaluated")
  expect_identical(result$status, "no_detected_perturbation")
  tse <- recovery_parent()
  expanded <- tse[, c(seq_len(ncol(tse)), 1)]
  colnames(expanded) <- c(colnames(tse), "new_sample")
  expect_warning(
    added <- recovery_sensitivity(expanded, "antibiotic", sensitivity_rules()[1, ]),
    class = "recoverome_warning_scope"
  )
  expect_identical(added$confirmation_time, 6)
})

test_that("unsupported comparison formats differ from incoherent required stages", {
  tse <- recovery_parent()
  record <- registration_record(tse)
  record$deviation$provenance$fingerprint_format <- "future"
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record
  result <- recovery_sensitivity(tse, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(result$evaluation_reason, "validation_incomplete")
  expect_true(is.na(result$structural_valid))
  record$deviation$schema_version <- 99L
  S4Vectors::metadata(tse)$recoverome$analyses$antibiotic <- record
  expect_error(recovery_sensitivity(tse, "antibiotic", sensitivity_rules()),
               class = "recoverome_error_input")
  broken <- recovery_parent()
  SummarizedExperiment::colData(broken)$rec_antibiotic_deviation[2] <- .1
  expect_error(recovery_sensitivity(broken, "antibiotic", sensitivity_rules()),
               class = "recoverome_error_input")
  expect_error(recovery_sensitivity(register_fixture(recovery_fixture()), "antibiotic",
                                    sensitivity_rules()), class = "recoverome_error_input")
})

test_that("rule failures retain their cause and identify the scenario", {
  tse <- recovery_parent()
  rules <- sensitivity_rules()
  rules$max_gap[2] <- 0
  error <- tryCatch(recovery_sensitivity(tse, "antibiotic", rules), error = identity)
  expect_s3_class(error, "recoverome_error_input")
  expect_identical(error$component, "rules")
  expect_identical(error$ids, "short_gap")
  expect_s3_class(error$parent, "recoverome_error_input")
  expect_identical(error$parent$ids, "max_gap")
  rules <- sensitivity_rules()
  rules$scenario_id[2] <- rules$scenario_id[1]
  expect_error(recovery_sensitivity(tse, "antibiotic", rules), class = "recoverome_error_input")
  expect_error(recovery_sensitivity(tse, "antibiotic", rules[FALSE, ]),
               class = "recoverome_error_input")
  rules <- sensitivity_rules()
  rules$threshold <- matrix(.25, nrow(rules), 1)
  expect_error(recovery_sensitivity(tse, "antibiotic", rules), class = "recoverome_error_input")
})

test_that("sensitivity validates the selected analysis only once", {
  tse <- recovery_parent()
  counter <- new.env(parent = emptyenv())
  counter$n <- 0L
  validate <- .recovery_validate_input
  testthat::local_mocked_bindings(.recovery_validate_input = function(...) {
    counter$n <- counter$n + 1L
    validate(...)
  })
  recovery_sensitivity(tse, "antibiotic", sensitivity_rules())
  expect_identical(counter$n, 1L)
})


test_that("an absent assay remains distinct from independently detected changes", {
  tse <- recovery_parent()
  SummarizedExperiment::assayNames(tse) <- "renamed"
  result <- recovery_sensitivity(tse, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(result$evaluation_reason, "historical_inputs_unavailable")
  expect_identical(result$dependencies, "changed")
  SummarizedExperiment::colData(tse)$day[2] <- 12
  changed <- recovery_sensitivity(tse, "antibiotic", sensitivity_rules()[1, ])
  expect_identical(changed$evaluation_reason, "inputs_changed")
})


test_that("rule horizons preserve unresolved overlapping events", {
  fixture <- recovery_fixture()
  fixture$events <- rbind(fixture$events, data.frame(
    event_id = "second", episode_id = "episode_1", start_time = 19, end_time = 20
  ))
  tse <- recovery_parent(fixture)
  result <- recovery_sensitivity(tse, "antibiotic", sensitivity_rules()[c(1, 4), ])
  expect_identical(result$evaluation_state, c("evaluated", "evaluated"))
  expect_identical(result$status, c("not_evaluable", "unconfirmed_return"))
  expect_identical(result$reason, c("unresolved_events", NA_character_))
})
