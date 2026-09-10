test_that("the accepted trajectories produce independently specified outcomes", {
  cases <- list(
    list(t = c(0, 2, 4, 6, 12), d = c(0.75, 0.25, 0.125, 0.125, 0.875),
         status = "confirmed_return", times = c(0, 2, 2, 6, NA, 12), visits = 4L,
         coverage = "reaches_horizon"),
    list(t = c(0, 2, 4), d = c(0.75, 0.25, 0.125),
         status = "unconfirmed_return", times = c(0, 2, 2, NA, NA, 4), visits = 3L,
         coverage = "ends_before_horizon"),
    list(t = c(0, 2, 3, 5, 7, 9), d = c(0.75, 0.125, 0.5, 0.125, 0.125, 0.125),
         status = "confirmed_return", times = c(0, 2, 5, 9, NA, 9), visits = 6L,
         coverage = "ends_before_horizon"),
    list(t = c(0, 2, 4, 6, 8, 10), d = c(0.75, 0.125, 0.125, 0.125, 0.5, 0.125),
         status = "confirmed_return", times = c(0, 2, 2, 6, 8, 10), visits = 6L,
         coverage = "reaches_horizon"),
    list(t = c(0, 2, 7, 9), d = c(0.75, 0.125, 0.125, 0.125),
         status = "unconfirmed_return", times = c(0, 2, 2, NA, NA, 9), visits = 4L,
         coverage = "ends_before_horizon"),
    list(t = c(0, 4, 8), d = c(0.75, 0.5, 0.375),
         status = "no_observed_return", times = c(0, NA, NA, NA, NA, 8), visits = 3L,
         coverage = "ends_before_horizon"),
    list(t = c(2, 6, 12), d = c(0.25, 0.125, 0.75),
         status = "no_detected_perturbation", times = c(NA, NA, NA, NA, NA, 12), visits = 2L,
         coverage = "reaches_horizon"),
    list(t = 12, d = 0.75,
         status = "not_evaluable", times = c(NA, NA, NA, NA, NA, 12), visits = 0L,
         coverage = "reaches_horizon"),
    list(t = c(0, 2, 2, 4, 6, 8), d = c(0.75, 0.125, 0.375, 0.125, 0.125, 0.125),
         status = "confirmed_return", times = c(0, 4, 4, 8, NA, 8), visits = 5L,
         coverage = "ends_before_horizon")
  )
  for (case in cases) {
    tse <- recovery_parent(recovery_fixture(case$t, case$d))
    before <- serialize(tse, NULL)
    out <- add_recovery(tse, "antibiotic", observed_rule())
    record <- registration_record(out)$recovery
    outcome <- record$episodes
    expect_identical(serialize(tse, NULL), before)
    expect_identical(outcome$status, case$status)
    expected_reason <- if (case$status == "not_evaluable") {
      "no_observations_in_window"
    } else {
      NA_character_
    }
    expect_identical(outcome$reason, expected_reason)
    expect_identical(outcome$coverage, case$coverage)
    expect_identical(outcome$n_window_visits, case$visits)
    actual_times <- unlist(as.list(outcome[5:10]), use.names = FALSE)
    expect_identical(actual_times, case$times)
    report <- validate_recovery(out)
    expect_true(report$summary$structural_valid)
    expect_true(report$summary$validation_complete)
    expect_identical(report$summary$dependencies, "unchanged")
  }
})

test_that("boundary equality, simultaneous visits and end origins follow the rule", {
  rule <- observed_rule()
  rule$persistence <- 6
  tse <- recovery_parent(recovery_fixture(c(0, 4, 7, 10), c(0.75, 0.25, 0.25, 0.25)))
  outcome <- registration_record(add_recovery(tse, "antibiotic", rule))$recovery$episodes
  expect_identical(outcome$confirmation_time, 10)
  expect_identical(outcome$candidate_time, 4)

  tied <- recovery_parent(recovery_fixture(c(0, 2, 2), c(0.75, 0.25, 0.25)))
  record <- registration_record(add_recovery(tied, "antibiotic", observed_rule()))$recovery
  expect_identical(record$episodes$status, "unconfirmed_return")
  expect_identical(record$evidence$episode_1$candidate, c("s2", "s3"))
  expect_identical(record$episodes$n_window_visits, 2L)

  ended <- recovery_parent(recovery_fixture(c(-2, 0, 2, 4), c(0.75, 0.25, 0.125, 0.125), "end"))
  record <- registration_record(add_recovery(ended, "antibiotic", observed_rule()))$recovery
  expect_identical(record$episodes$first_perturbation_time, -2)
  expect_identical(record$episodes$candidate_time, 0)
  expect_identical(record$episodes$confirmation_time, 4)
  expect_identical(record$evidence$episode_1$confirmation_run, c("s2", "s3", "s4"))

  rule$threshold <- 1
  expect_identical(
    registration_record(add_recovery(tse, "antibiotic", rule))$recovery$episodes$status,
    "no_detected_perturbation"
  )
  rule <- observed_rule()
  rule$persistence <- 11
  expect_identical(
    registration_record(add_recovery(tse, "antibiotic", rule))$recovery$episodes$status,
    "unconfirmed_return"
  )
})

test_that("episode outcomes add metadata only and preserve registered evidence ordering", {
  tse <- recovery_parent()
  # Deliberately change current order; evidence still uses historical time and tie order.
  reordered <- tse[, c("s6", "s4", "s2", "b1", "s5", "s3", "s1")]
  out <- add_recovery(reordered, "antibiotic", observed_rule())
  record <- registration_record(out)$recovery
  expect_identical(record$dependencies$sample_ids, c("b1", paste0("s", 1:6)))
  expect_identical(record$evidence$episode_1$evaluated, paste0("s", 1:6))
  expect_identical(record$evidence$episode_1$confirmation_run, c("s2", "s3", "s4"))
  expect_identical(record$evidence$episode_1$rebound, "s5")
  expect_identical(SummarizedExperiment::colData(out), SummarizedExperiment::colData(reordered))
  metadata <- S4Vectors::metadata(out)
  metadata$recoverome$analyses$antibiotic$recovery <- NULL
  S4Vectors::metadata(out) <- metadata
  expect_identical(out, reordered)
})


test_that("adding outcomes preserves trees, links and other named analyses", {
  fixture <- registration_fixture(trees = TRUE)
  fixture$tse <- register_fixture(fixture, analysis_id = "other")
  parent <- recovery_parent(fixture, reference = c("s1", "s4"))
  before <- serialize(parent, NULL)
  out <- add_recovery(parent, "antibiotic", observed_rule())
  expect_identical(serialize(parent, NULL), before)
  expect_true(all(validate_recovery(out)$summary$structural_valid))
  expect_identical(names(SummarizedExperiment::colData(out)),
                   names(SummarizedExperiment::colData(parent)))
  S4Vectors::metadata(out)$recoverome$analyses$antibiotic$recovery <- NULL
  expect_identical(out, parent)
})
