test_that("short follow-up and a filtered completed analysis have different meanings", {
  fixture <- recovery_fixture()
  complete <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  history <- registration_record(complete)$recovery
  expect_identical(history$episodes$confirmation_time, 6)
  expect_identical(history$episodes$rebound_time, 8)

  cases <- list(
    list(last = 1L, status = "no_observed_return", candidate = NA_real_,
         confirmation = NA_real_, rebound = NA_real_, time = 0),
    list(last = 3L, status = "unconfirmed_return", candidate = 2,
         confirmation = NA_real_, rebound = NA_real_, time = 4),
    list(last = 4L, status = "confirmed_return", candidate = 2,
         confirmation = 6, rebound = NA_real_, time = 6),
    list(last = 5L, status = "confirmed_return", candidate = 2,
         confirmation = 6, rebound = 8, time = 8)
  )
  for (case in cases) {
    ids <- c("b1", paste0("s", seq_len(case$last)))
    short_fixture <- fixture
    short_fixture$tse <- fixture$tse[, ids]
    fresh <- add_recovery(recovery_parent(short_fixture), "antibiotic", observed_rule())
    outcome <- registration_record(fresh)$recovery$episodes
    expect_identical(outcome$status, case$status)
    expect_identical(outcome$first_perturbation_time, 0)
    expect_identical(outcome$first_return_time, case$candidate)
    expect_identical(outcome$candidate_time, case$candidate)
    expect_identical(outcome$confirmation_time, case$confirmation)
    expect_identical(outcome$rebound_time, case$rebound)
    expect_identical(outcome$coverage, "ends_before_horizon")
    expect_identical(outcome$last_observed_time, case$time)
    expect_identical(outcome$n_window_visits, case$last)
    expect_validation_state(
      validate_preserving_input(fresh),
      n_registered = length(ids),
      n_retained = length(ids)
    )

    historical <- complete[, ids]
    expect_identical(SummarizedExperiment::assay(historical), SummarizedExperiment::assay(fresh))
    expect_identical(registration_record(historical)$recovery, history)
    report <- validate_preserving_input(historical)
    expect_validation_state(
      report,
      validation_complete = FALSE,
      dependencies = "not_checked",
      sample_scope = "subset",
      n_registered = 7L,
      n_retained = length(ids)
    )
    expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info",
                                 setdiff(colnames(complete), ids))
  }
})

test_that("removing each evidence role or every visit preserves the entire historical record", {
  complete <- add_recovery(recovery_parent(), "antibiotic", observed_rule())
  history <- registration_record(complete)
  evidence <- history$recovery$evidence$episode_1
  expect_identical(evidence$perturbation, "s1")
  expect_identical(evidence$candidate, "s2")
  expect_identical(evidence$confirmation_run, c("s2", "s3", "s4"))
  expect_identical(evidence$confirmation, "s4")
  expect_identical(evidence$rebound, "s5")

  removals <- list("b1", "s1", "s2", "s4", "s5", "s6", c("b1", paste0("s", 1:6)))
  for (removed in removals) {
    retained <- setdiff(colnames(complete), removed)
    filtered <- complete[, rev(retained), drop = FALSE]
    expect_identical(registration_record(filtered), history)
    report <- validate_preserving_input(filtered)
    scope <- if (length(retained)) "subset" else "empty"
    expect_validation_state(
      report,
      validation_complete = FALSE,
      dependencies = "not_checked",
      sample_scope = scope,
      n_registered = 7L,
      n_retained = length(retained)
    )
    expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info", removed)
  }
})

test_that("discarding a discordant tied sample cannot advance historical confirmation", {
  fixture <- recovery_fixture(c(0, 2, 2, 4, 6, 8), c(0.75, 0.125, 0.375, 0.125, 0.125, 0.125))
  complete <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  saved <- registration_record(complete)$recovery
  expect_identical(saved$episodes$candidate_time, 4)
  expect_identical(saved$episodes$confirmation_time, 8)
  expect_identical(saved$evidence$episode_1$confirmation_run, c("s4", "s5", "s6"))

  ids <- c("b1", "s1", "s2", "s4", "s5", "s6")
  filtered <- complete[, ids]
  expect_identical(registration_record(filtered)$recovery, saved)
  report <- validate_preserving_input(filtered)
  expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info", "s3")
  expect_identical(report$summary$dependencies, "not_checked")
  expect_false(report$summary$validation_complete)

  fixture$tse <- fixture$tse[, ids]
  fresh <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  outcome <- registration_record(fresh)$recovery
  expect_identical(outcome$episodes$candidate_time, 2)
  expect_identical(outcome$episodes$confirmation_time, 6)
  expect_identical(outcome$evidence$episode_1$confirmation_run, c("s2", "s4", "s5"))
})

test_that("removing an outside-horizon visit preserves its historical coverage only", {
  fixture <- recovery_fixture(c(0, 2, 4, 6, 12), c(0.75, 0.25, 0.125, 0.125, 0.875))
  complete <- add_recovery(recovery_parent(fixture), "antibiotic", observed_rule())
  history <- registration_record(complete)$recovery
  expect_identical(history$episodes$coverage, "reaches_horizon")
  expect_identical(history$episodes$last_observed_time, 12)
  expect_identical(history$episodes$confirmation_time, 6)
  expect_identical(history$episodes$rebound_time, NA_real_)
  expect_identical(history$evidence$episode_1$evaluated, paste0("s", 1:4))
  expect_identical(history$evidence$episode_1$coverage, paste0("s", 1:5))

  filtered <- complete[, colnames(complete) != "s5"]
  report <- validate_preserving_input(filtered)
  expect_identical(registration_record(filtered)$recovery, history)
  expect_validation_diagnostic(report, "RECOVERY_INPUT_MISSING", "info", "s5")
  expect_false(report$summary$validation_complete)
  expect_identical(report$summary$dependencies, "not_checked")
})
